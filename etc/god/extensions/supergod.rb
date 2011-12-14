require "socket"
# Additional status information
# Health defined for groups
# A god which can control other gods
module God
  #patched version to allow network access
  # The God::Server oversees the DRb server which dishes out info on this God daemon.
  class Socket
    # The address of the socket for a given port
    #   +port+ is the port number
    #
    # Returns String (drb address)
    def self.socket(port)
      "druby://0.0.0.0:#{port}"
    end

  end
end

