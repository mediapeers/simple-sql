class Simple::SQL::Connection
end

require_relative "connection/raw_connection"
require_relative "connection/active_record_connection"

require_relative "connection/base"
require_relative "connection/lock"
require_relative "connection/scope"
require_relative "connection/reflection"
require_relative "connection/insert"
require_relative "connection/duplicate"
require_relative "connection/type_info"

# A Connection object.
#
# A Connection object is built around a raw connection (as created from the pg
# ruby gem).
#
#
# It includes
# the ConnectionAdapter, which implements ask, all, + friends, and also
# includes a quiet simplistic Transaction implementation
class Simple::SQL::Connection
  def self.create(database_url = :auto)
    case database_url
    when :auto
      if defined?(::ActiveRecord)
        ActiveRecordConnection.new
      else
        RawConnection.new Simple::SQL::Config.determine_url
      end
    else
      RawConnection.new database_url
    end
  end

  extend Forwardable
  delegate [:wait_for_notify] => :raw_connection
end
