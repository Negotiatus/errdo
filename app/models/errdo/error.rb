module Errdo
  class Error < ActiveRecord::Base

    paginates_per 20

    self.table_name = Errdo.error_name

    enum status: [:active, :wontfix, :resolved]

    serialize :backtrace

    has_many :error_occurrences
    belongs_to :last_experiencer, polymorphic: true

    before_validation :create_unique_string

    validates :backtrace_hash, uniqueness: true

    def self.find_or_create(params)
      params = clean_backtrace(params)
      unique_string = create_unique_string_from_params(params)

      @error = Errdo::Error.find_by(backtrace_hash: unique_string)
      @error = Errdo::Error.create(params) if @error.nil?

      return @error
    end

    # I need a more elegant way to do this
    def self.create_unique_string_from_params(params)
      Digest::SHA1.hexdigest(
        params[:backtrace].reject { |l| l[%r{\/ruby-[0-9]\.[0-9]\.[0-9]\/|_test.rb}] }.join("") +
        params[:exception_message].to_s.gsub(/:0x[0-f]{14}/, "") +
        params[:exception_class_name].to_s
      ).to_s
    end

    def short_backtrace
      backtrace.first if backtrace.respond_to?(:first)
    end

    def self.clean_backtrace(params)
      unless params[:backtrace].empty?
        params[:backtrace][0] = params[:backtrace][0].gsub(/[_]{1,}[0-9]+/, "")
      end
      return params
    end

    private

    def create_unique_string
      self.backtrace_hash =
        Digest::SHA1.hexdigest(backtrace.to_a.reject { |l| l[%r{\/ruby-[0-9]\.[0-9]\.[0-9]\/|_test.rb}] }.join("") +
                               exception_message.to_s.gsub(/:0x[0-f]{14}/, "") +
                               exception_class_name.to_s).to_s
    end

  end
end
