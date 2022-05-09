module ManageIQ::Providers::CiscoIntersight
  class PhysicalInfraManager::EventCatcher::Stream
    class ProviderUnreachable < ManageIQ::Providers::BaseManager::EventCatcher::Runner::TemporaryFailure
    end

    def initialize(ems, options = {})
      @ems = ems
      @last_activity = nil
      @stop_polling = false
      @poll_sleep = options[:poll_sleep] || 20.seconds


    end

    def start
      @stop_polling = false
    end

    def stop
      @stop_polling = true
    end

    def poll
      since = Time.new(2000).utc.iso8601    ## Fetching all Alerts/Workflow infos since the year 2000. Should be part of config?
      loop do
        @ems.with_provider_connection do |api_client|
          catch(:stop_polling) do
            @cond_api_opts = {
              filter: 'CreateTime gt '+since.to_s,
            }
            events = IntersightClient::CondApi.new(api_client).get_cond_alarm_list(@cond_api_opts).results
            @workflow_api_opts = {
              filter: 'CreateTime gt '+since.to_s,
              select: '$select=CreateTime,ModTime,Name,Status,Email,WorkflowCtx', # Use only selected attributes. Validation of other within the SDK lib might fail
            }
            workflow_infos = IntersightClient::WorkflowApi.new(api_client).get_workflow_workflow_info_list(@workflow_api_opts).results
            since = Time.now.utc.iso8601
            break if @stop_polling
            events.each { |event| yield event }
          rescue => exception
            raise ProviderUnreachable, exception.message
          end
        end
        sleep(@poll_sleep)
      end
    end
  end
end
