require 'spec_helper'

describe RSpec::Rebound do
  class RetryError < StandardError; end
  class RetryChildError < RetryError; end
  class HardFailError < StandardError; end
  class HardFailChildError < HardFailError; end
  class OtherError < StandardError; end
  class SharedError < StandardError; end

  def count
    @count ||= 0
  end

  def count_up
    @count = count + 1
  end

  def set_expectations(expectations)
    @expectations = expectations
  end

  def shift_expectation
    @expectations.shift
  end

  before(:context) do
    ENV.delete('RSPEC_REBOUND_RETRY_COUNT')
  end

  context 'with no retry option' do
    it 'works correctly' do
      expect(true).to be true
    end
  end

  context 'with retry option' do
    before { count_up }

    context 'when the test fails until the last attempt' do
      before(:context) { set_expectations([false, false, true]) }

      it 'runs the example until :retry times', retry: 3 do
        expect(shift_expectation).to be true
        expect(count).to eq(3)
      end
    end

    context 'when the test succeeds before the last attempt' do
      before(:context) { set_expectations([false, true, false]) }

      it 'stops retrying if the example succeeds', retry: 3 do
        expect(shift_expectation).to be true
        expect(count).to eq(2)
      end
    end

    context 'with a lambda condition for retry count' do
      before(:context) { set_expectations([false, true]) }

      it "gets the retry count from the condition's call", :retry_me_once do
        expect(shift_expectation).to be true
        expect(count).to eq(2)
      end
    end

    context 'with retry: 0' do
      around do |example|
        count_before_run = count
        example.run
        expect(count).to eq(count_before_run + 1)
      end

      it 'runs only once', retry: 0 do
        # Test logic is in the around hook to correctly capture state
        # before and after the parent's before hook runs.
      end
    end

    context 'with the RSPEC_REBOUND_RETRY_COUNT environment variable' do
      before(:context) do
        @original_env = ENV['RSPEC_REBOUND_RETRY_COUNT']
        ENV['RSPEC_REBOUND_RETRY_COUNT'] = '3'
        set_expectations([false, false, true])
      end

      after(:context) do
        ENV['RSPEC_REBOUND_RETRY_COUNT'] = @original_env
      end

      it 'overrides the retry count set in an example', retry: 2 do
        expect(shift_expectation).to be true
        expect(count).to eq(3)
      end
    end

    context 'with exponential backoff enabled' do
      before(:context) do
        set_expectations([false, false, true])
        @start_time = Time.now
      end

      it 'waits between retries', :exponential_backoff, retry: 3, retry_wait: 0.001 do
        expect(shift_expectation).to be true
        expect(count).to eq(3)
        expect(Time.now - @start_time).to be >= 0.001
      end
    end

    describe 'with a list of exceptions to immediately fail on', exceptions_to_hard_fail: [HardFailError], retry: 2 do
      context 'when the example throws an exception in the hard fail list' do
        it 'does not retry' do
          expect(count).to be < 2
          pending "This should fail with a count of 1: Count was #{count}"
          raise HardFailError unless count > 1
        end
      end

      context 'when the example throws a child of an exception in the hard fail list' do
        it 'does not retry' do
          expect(count).to be < 2
          pending "This should fail with a count of 1: Count was #{count}"
          raise HardFailChildError unless count > 1
        end
      end

      context 'when the example throws an exception not in the hard fail list' do
        it 'retries the maximum number of times' do
          raise OtherError unless count > 1
          expect(count).to eq(2)
        end
      end
    end

    describe 'with a list of exceptions to retry on', exceptions_to_retry: [RetryError], retry: 2 do
      context 'tracking retry metadata' do
        let(:example_code) do
          %{
            $count ||= 0
            $count += 1
            raise NameError unless $count > 2
          }
        end

        let!(:example_group) do
          $count, $example_code = 0, example_code

          RSpec.describe('example group', exceptions_to_retry: [NameError], retry: 3).tap do |group|
            group.example('tracks attempts') { instance_eval($example_code) }
            group.run
          end
        end

        it 'matches attempts metadata after retries' do
          example = example_group.examples.first
          expect(example.metadata[:retry_attempts]).to eq(2)
        end

        it 'adds exceptions into retry_exceptions metadata array' do
          example = example_group.examples.first
          exceptions = example.metadata[:retry_exceptions]
          expect(exceptions.count).to eq(2)
          expect(exceptions).to all(be_an_instance_of(NameError))
        end
      end

      context 'when the example throws an exception in the retry list' do
        it 'retries the maximum number of times' do
          raise RetryError unless count > 1
          expect(count).to eq(2)
        end
      end

      context 'when the example throws a child of an exception in the retry list' do
        it 'retries the maximum number of times' do
          raise RetryChildError unless count > 1
          expect(count).to eq(2)
        end
      end

      context 'when the example fails with an exception not in the retry list' do
        it 'runs only once' do
          set_expectations([false])
          expect(count).to eq(1)
        end
      end

      context 'when exceptions are matched with case equality (===)' do
        class CaseEqualityError < StandardError
          def self.===(other)
            other.is_a?(StandardError) && other.message == 'Rescue me!'
          end
        end

        it 'retries the maximum number of times', exceptions_to_retry: [CaseEqualityError] do
          raise StandardError, 'Rescue me!' unless count > 1
          expect(count).to eq(2)
        end
      end
    end

    describe 'with both hard fail and retry lists', exceptions_to_hard_fail: [SharedError, HardFailError], exceptions_to_retry: [SharedError, RetryError], retry: 2 do
      context 'when the exception exists in both lists' do
        it 'does not retry because the hard fail list takes precedence' do
          expect(count).to be < 2
          pending "This should fail with a count of 1: Count was #{count}"
          raise SharedError unless count > 1
        end
      end

      context 'when the exception is only in the hard fail list' do
        it 'does not retry' do
          expect(count).to be < 2
          pending "This should fail with a count of 1: Count was #{count}"
          raise HardFailError unless count > 1
        end
      end

      context 'when the exception is only in the retry list' do
        it 'retries the maximum number of times' do
          raise RetryError unless count > 1
          expect(count).to eq(2)
        end
      end

      context 'when the exception is in neither list' do
        it 'does not retry' do
          expect(count).to be < 2
          pending "This should fail with a count of 1: Count was #{count}"
          raise OtherError unless count > 1
        end
      end
    end
  end

  describe 'clearing lets' do
    before(:context) do
      @control = true
    end

    let(:let_based_on_control) { @control }

    after do
      @control = false
    end

    it 'clears the let variable when the test fails so it can be reset', retry: 2 do
      expect(let_based_on_control).to be false
    end

    it 'does not clear the let variable when disabled', clear_lets_on_failure: false, retry: 2 do
      expect(let_based_on_control).to be !@control
    end
  end

  describe 'running example.run_with_retry in an around filter', retry: 2 do
    before { count_up }
    before(:context) { set_expectations([false, false, true]) }

    it 'allows retry options to be overridden', :overridden do
      expect(RSpec.current_example.metadata[:retry]).to eq(3)
    end

    it 'uses the overridden options to retry', :overridden do
      expect(shift_expectation).to be true
      expect(count).to eq(3)
    end
  end

  describe 'calling retry_callback between retries', retry: 2 do
    before(:context) do
      RSpec.configuration.retry_callback = proc do |example|
        @retry_callback_called = true
        @example_from_callback = example
      end
    end

    after(:context) do
      RSpec.configuration.retry_callback = nil
    end

    context 'on failure' do
      before(:context) do
        @retry_callback_called = false
        @example_from_callback = nil
        @retry_attempts = 0
      end

      it 'calls the configured retry callback with example metadata', with_some: 'metadata' do |example|
        if @retry_attempts == 0
          @retry_attempts += 1
          expect(@retry_callback_called).to be false
          expect(@example_from_callback).to be_nil
          raise "let's retry once!"
        else
          expect(@retry_callback_called).to be true
          expect(@example_from_callback).to eq(example)
          expect(@example_from_callback.metadata[:with_some]).to eq('metadata')
        end
      end
    end

    context 'on success' do
      before(:context) do
        @retry_callback_called = false
        @example_from_callback = nil
      end

      after do
        expect(@retry_callback_called).to be false
        expect(@example_from_callback).to be_nil
      end

      it 'does not call the retry_callback' do
      end
    end
  end

  describe 'Example::Procsy#attempts' do
    let!(:example_group) do
      RSpec.describe do
        class ReboundResults
          class << self
            attr_accessor :results
          end
          self.results = {}
        end

        around do |example|
          example.run_with_retry
          ReboundResults.results[example.description] = [example.exception.nil?, example.attempts]
        end

        it 'without retry option' do
          expect(true).to be true
        end

        it 'with retry option', retry: 2 do
          expect(true).to be false
        end
      end
    end

    it 'is exposed' do
      example_group.run
      expect(ReboundResults.results).to eq({
        'without retry option' => [true, 1],
        'with retry option' => [false, 3]
      })
    end
  end

  describe 'Flaky callback detection' do
    let!(:example_group) do
      RSpec.describe do
        class FlakyTestResults
          class << self
            attr_accessor :results, :flaky_test_callback_called
          end
          self.results = {}
          self.flaky_test_callback_called = nil
        end

        def expectations
          @expectations ||= [false, true]
        end

        before(:context) do
          RSpec.configuration.flaky_test_callback = proc do |example|
            FlakyTestResults.flaky_test_callback_called = example.description
          end
        end

        after(:context) do
          RSpec.configuration.flaky_test_callback = nil
        end

        around do |example|
          example.run_with_retry
          FlakyTestResults.results[example.description] = [example.exception.nil?, example.attempts]
        end

        it 'without retry option', retry: 0 do
          expect(true).to be false
        end

        it 'with retry option', retry: 1 do
          expect(expectations.shift).to be true
        end
      end
    end

    it 'calls the flaky test callback on success after a retry' do
      example_group.run
      expect(FlakyTestResults.results).to eq({
        'without retry option' => [false, 1],
        'with retry option' => [true, 2]
      })
      expect(FlakyTestResults.flaky_test_callback_called).to eq("with retry option")
    end
  end

  describe 'output in verbose mode' do
    line_1 = __LINE__ + 8
    line_2 = __LINE__ + 11
    let(:group) do
      RSpec.describe 'ExampleGroup', retry: 1 do
        after do
          fail 'broken after hook'
        end

        it 'passes' do
          true
        end

        it 'fails' do
          fail 'broken spec'
        end
      end
    end

    it 'outputs failures correctly' do
      output_stream = StringIO.new
      RSpec.configuration.output_stream = output_stream
      RSpec.configuration.verbose_retry = true
      RSpec.configuration.display_try_failure_messages = true

      group.run RSpec.configuration.reporter

      expected_output = <<-STRING.gsub(/^\s+\| ?/, '')
        | 1st Try error in ./spec/lib/rspec/rebound_spec.rb:#{line_1}:
        | broken after hook
        |
        | RSpec::Rebound: 2nd try ./spec/lib/rspec/rebound_spec.rb:#{line_1}
        | F
        | 1st Try error in ./spec/lib/rspec/rebound_spec.rb:#{line_2}:
        | broken spec
        | broken after hook
        |
        | RSpec::Rebound: 2nd try ./spec/lib/rspec/rebound_spec.rb:#{line_2}
      STRING
      expect(output_stream.string).to include(expected_output)
    end
  end
end
