require 'rspec/core'
require 'rspec/rebound/version'
require 'rspec_ext/rspec_ext'

module RSpec
  class Rebound
    def self.setup
      RSpec.configure do |config|
        config.add_setting :verbose_retry, default: false
        config.add_setting :default_retry_count, default: 0
        config.add_setting :default_sleep_interval, default: 0
        config.add_setting :exponential_backoff, default: false
        config.add_setting :clear_lets_on_failure, default: true
        config.add_setting :display_try_failure_messages, default: false

        # retry based on example metadata
        config.add_setting :retry_count_condition, default: ->(_) { nil }

        # If a list of exceptions is provided and 'retry' > 1, we only retry if
        # the exception that was raised by the example is NOT in that list. Otherwise
        # we ignore the 'retry' value and fail immediately.
        #
        # If no list of exceptions is provided and 'retry' > 1, we always retry.
        config.add_setting :exceptions_to_hard_fail, default: []

        # If a list of exceptions is provided and 'retry' > 1, we only retry if
        # the exception that was raised by the example is in that list. Otherwise
        # we ignore the 'retry' value and fail immediately.
        #
        # If no list of exceptions is provided and 'retry' > 1, we always retry.
        config.add_setting :exceptions_to_retry, default: []

        # Callback between retries
        config.add_setting :retry_callback, default: nil

        # Callback for flaky tests
        config.add_setting :flaky_test_callback, default: nil

        # If true, flaky tests will be detected and reported, even if the retry count is set to 0.
        # This is useful for detecting flaky tests that are not being retried.
        config.add_setting :flaky_spec_detection, default: false

        config.around(:each, &:run_with_retry)
      end
    end

    attr_reader :context, :initial_example

    def initialize(initial_example, opts = {})
      @initial_example = initial_example
      @initial_example.metadata.merge!(opts)
      current_example.attempts ||= 0
    end

    def current_example
      @current_example ||= RSpec.current_example
    end

    def retry_count
      [
        (
        ENV['RSPEC_REBOUND_RETRY_COUNT'] ||
            initial_example.metadata[:retry] ||
            RSpec.configuration.retry_count_condition.call(initial_example) ||
            RSpec.configuration.default_retry_count
      ).to_i,
        0
      ].max
    end

    def attempts
      current_example.attempts ||= 0
    end

    def attempts=(val)
      current_example.attempts = val
    end

    def clear_lets
      if !initial_example.metadata[:clear_lets_on_failure].nil?
        initial_example.metadata[:clear_lets_on_failure]
      else
        RSpec.configuration.clear_lets_on_failure
      end
    end

    def sleep_interval
      if initial_example.metadata[:exponential_backoff]
        2**(current_example.attempts - 1) * initial_example.metadata[:retry_wait]
      else
        initial_example.metadata[:retry_wait] ||
          RSpec.configuration.default_sleep_interval
      end
    end

    def exceptions_to_hard_fail
      initial_example.metadata[:exceptions_to_hard_fail] ||
        RSpec.configuration.exceptions_to_hard_fail
    end

    def exceptions_to_retry
      initial_example.metadata[:exceptions_to_retry] ||
        RSpec.configuration.exceptions_to_retry
    end

    def verbose_retry?
      RSpec.configuration.verbose_retry?
    end

    def display_try_failure_messages?
      RSpec.configuration.display_try_failure_messages?
    end

    def run
      new_example = current_example
      loop do
        if attempts.positive?
          RSpec.configuration.formatters.each { |f| f.retry(new_example) if f.respond_to? :retry }
          if verbose_retry?
            message = "RSpec::Rebound: #{ordinalize(attempts + 1)} try #{new_example.location}"
            message = "\n#{message}" if attempts == 1
            RSpec.configuration.reporter.message(message)
          end
        end

        new_example.metadata[:retry_attempts] = attempts
        new_example.metadata[:retry_exceptions] ||= []

        new_example.clear_exception
        initial_example.run

        # If it's a flaky test, call the callback
        if new_example.exception.nil? && attempts.positive?
          if RSpec.configuration.flaky_test_callback
            new_example.example_group_instance.instance_exec(new_example, &RSpec.configuration.flaky_test_callback)
          end

          if flaky_spec_detection?(attempts)
            display_try_failure_message(new_example, attempts, retry_count) if display_try_failure_messages?
            new_example.exception = new_example.metadata[:retry_exceptions].last
          end
        end

        self.attempts += 1

        break if new_example.exception.nil?

        new_example.metadata[:retry_exceptions] << new_example.exception

        break if !flaky_spec_detection?(attempts) && attempts >= retry_count + 1

        break if exceptions_to_hard_fail.any? && exception_exists_in?(exceptions_to_hard_fail, new_example.exception)

        break if exceptions_to_retry.any? && !exception_exists_in?(exceptions_to_retry, new_example.exception)

        display_try_failure_message(new_example, attempts, retry_count) if verbose_retry? && display_try_failure_messages?

        new_example.example_group_instance.clear_lets if clear_lets

        # If the callback is defined, let's call it
        if RSpec.configuration.retry_callback
          new_example.example_group_instance.instance_exec(new_example, &RSpec.configuration.retry_callback)
        end

        if RSpec.configuration.flaky_spec_detection && attempts.positive? && new_example.exception.nil?
          new_example.example_group_instance.instance_exec(new_example, &RSpec.configuration.flaky_spec_detection)
        end

        sleep sleep_interval if sleep_interval.to_f.positive?
      end
    end

    private

    # borrowed from ActiveSupport::Inflector
    def ordinalize(number)
      if (11..13).include?(number.to_i % 100)
        "#{number}th"
      else
        case number.to_i % 10
        when 1 then "#{number}st"
        when 2 then "#{number}nd"
        when 3 then "#{number}rd"
        else "#{number}th"
        end
      end
    end

    def exception_exists_in?(list, exception)
      list.any? do |exception_klass|
        exception.is_a?(exception_klass) || exception_klass === exception
      end
    end

    def flaky_spec_detection?(attempts)
      RSpec.configuration.flaky_spec_detection? && attempts == 1
    end

    def display_try_failure_message(example, attempts, retry_count)
      return if attempts == retry_count + 1

      exception_strings =
        if example.exception.is_a?(::RSpec::Core::MultipleExceptionError::InterfaceTag)
          example.exception.all_exceptions.map(&:to_s)
        else
          [example.exception.to_s]
        end

      try_message = "\n#{ordinalize(attempts)} Try error in #{example.location}:\n#{exception_strings.join "\n"}\n"
      RSpec.configuration.reporter.message(try_message)
    end
  end
end

RSpec::Rebound.setup
