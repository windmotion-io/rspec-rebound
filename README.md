# RSpec::Rebound

RSpec::Rebound adds a ``:retry`` option for intermittently failing rspec examples.
If an example has the ``:retry`` option, rspec will retry the example the
specified number of times until the example succeeds.

## Acknowledgments

This gem is derived from the [rspec-retry](https://github.com/NoRedInk/rspec-retry) gem by NoRedInk. We would like to express our sincere gratitude to NoRedInk for their original work. RSpec::Rebound is an updated, upgraded, and maintained version of that gem.

**Important migration note:** When moving from rspec-retry to rspec-rebound, you should subtract 1 from every `retry: X` value in your tests. In rspec-rebound, `retry: 2` means up to 2 retries (3 attempts total), whereas in rspec-retry it might have meant 2 attempts total. This change makes the retry count more intuitive.

### Compatibility

| Rspec Version | Rspec-Rebound Version |
|---------------|------------------------|
| > 3.3         | 0.1.0                  |
| < 3.3         | Use [rspec-retry](https://github.com/NoRedInk/rspec-retry) instead |


## Installation

Add this line to your application's Gemfile:

```ruby
gem 'rspec-rebound', group: :test # Unlike rspec, this doesn't need to be included in development group
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install rspec-rebound

require in ``spec_helper.rb``

```ruby
# spec/spec_helper.rb
require 'rspec/rebound'

RSpec.configure do |config|
  # show retry status in spec process
  config.verbose_retry = true
  # show exception that triggers a retry if verbose_retry is set to true
  config.display_try_failure_messages = true

  # run retry only on features
  config.around :each, :js do |ex|
    ex.run_with_retry retry: 3
  end

  # callback to be run when a flaky test is detected
  config.flaky_test_callback = proc do |example|
    Rspec::Watchdog::Reporter.report(example)
  end

  # callback to be run between retries
  config.retry_callback = proc do |ex|
    # run some additional clean up task - can be filtered by example metadata
    if ex.metadata[:js]
      Capybara.reset!
    end
  end
end
```

## Usage

```ruby
it 'should randomly succeed', :retry => 2 do
  expect(rand(2)).to eq(1)
end

it 'should succeed after a while', :retry => 2, :retry_wait => 10 do
  expect(command('service myservice status')).to eq('started')
end
# run spec (following log is shown if verbose_retry options is true)
# RSpec::Rebound: 2nd try ./spec/lib/random_spec.rb:49
# RSpec::Rebound: 3rd try ./spec/lib/random_spec.rb:49
```

### Calling `run_with_retry` programmatically

You can call `ex.run_with_retry(opts)` on an individual example.

## Configuration

- __:verbose_retry__(default: *false*) Print retry status
- __:display_try_failure_messages__ (default: *false*) If verbose retry is enabled, print what reason forced the retry
- __:default_retry_count__(default: *0*) If retry count is not set in an example, this value is used by default. This is a 'retry' count. If increased from the default of 0 to 1, if they fail all examples will be retried once (and 2 attempts in total).
- __:default_sleep_interval__(default: *0*) Seconds to wait between retries
- __:clear_lets_on_failure__(default: *true*) Clear memoized values for ``let``s before retrying
- __:exceptions_to_hard_fail__(default: *[]*) List of exceptions that will trigger an immediate test failure without retry. Takes precedence over __:exceptions_to_retry__
- __:exceptions_to_retry__(default: *[]*) List of exceptions that will trigger a retry (when empty, all exceptions will)
- __:retry_callback__(default: *nil*) Callback function to be called between retries
- __:flaky_test_callback__(default: *nil*) Callback function to be called when a flaky test is detected (when a test fails but then passes on a subsequent attempt)
- __:flaky_spec_detection__(default: *true*) If true, flaky tests will be detected and reported, even if the retry count is set to 0. This is useful for detecting flaky tests that are not being retried.

## Environment Variables
- __RSPEC_REBOUND_RETRY_COUNT__ can override the retry counts even if a retry count is set in an example or default_retry_count is set in a configuration.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a pull request
