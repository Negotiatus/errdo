module Errdo
  module Models
    class ErrorEnvParser

      attr_accessor :exception_class_name, :exception_message, :http_method,
                    :host_name, :url, :backtrace, :ip, :user_agent, :referer,
                    :query_string, :param_values, :cookie_values, :header_values,
                    :experiencer_id, :experiencer_type

      def initialize(env, user_parser)
        set_accessible_params(
          env,
          ActionDispatch::Request.new(env),
          env["action_controller.instance"],
          user_parser.user
        )
      end

      def error_hash
        {
          exception_class_name:   @exception_class_name,
          exception_message:      @exception_message,
          http_method:            @http_method,
          host_name:              @host_name,
          url:                    @url,
          backtrace:              @backtrace,
          last_experiencer_id:    @experiencer_id,
          last_experiencer_type:  @experiencer_type
        }
      end

      def error_occurrence_hash
        {
          ip:                   @ip,
          user_agent:           @user_agent,
          referer:              @referer,
          query_string:         @query_string,
          param_values:         @param_values,
          cookie_values:        @cookie_values,
          header_values:        @header_values,
          experiencer_id:       @experiencer_id,
          experiencer_type:     @experiencer_type
        }
      end

      def exception_name
        @exception_class_name
      end

      def short_backtrace
        @backtrace.first if @backtrace.respond_to?(:first)
      end

      def user
        @experiencer_type.constantize.find_by(id: @experiencer_id) if @experiencer_type && Errdo.error_name
      end

      private

      def set_accessible_params(env, request, controller, new_user)
        @exception_class_name = env["action_dispatch.exception"].class.to_s
        @exception_message =    env["action_dispatch.exception"].try(:message)
        @http_method =          deep_utf8_scrub(request.try(:request_method))
        @host_name =            deep_utf8_scrub(request.try(:server_name))
        @url =                  deep_utf8_scrub(request.try(:original_url))
        @backtrace =            prepare_backtrace(env)
        @ip =                   request.try(:ip)
        @user_agent =           deep_utf8_scrub(request.try(:user_agent))
        @referer =              request.try(:referer)
        @query_string =         deep_utf8_scrub(request.try(:query_string))
        @param_values =         deep_utf8_scrub(scrubbed_params(request))
        @cookie_values =        deep_utf8_scrub(request.try(:cookies))
        @header_values =        deep_utf8_scrub(controller.try(:headers))
        @experiencer_id =       new_user.try(:id)
        @experiencer_type =     new_user.try(:class).try(:name)
      end

      def prepare_backtrace(env)
        env["action_dispatch.exception"].try(:backtrace)
      end

      def scrubbed_params(request)
        params = request.try(:params) || {}
        Errdo.dirty_words.each do |word|
          params[word] = "..." if params[word]
        end
        # Remove all files
        params.each do |key, value|
          params[key] = value.headers if value.is_a? ActionDispatch::Http::UploadedFile
        end
        params
      end

      def deep_utf8_scrub(obj)
        if obj.respond_to? :each
          obj.each { |o| deep_utf8_scrub(o) }
        end
        if obj.is_a? String
          obj = obj.scrub!
        end
        return obj
      end

    end
  end
end
