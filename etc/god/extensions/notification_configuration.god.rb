
God::Contacts::Email.defaults do |d|
  d.from_email = 'god@agent5.3dsmx.com'
  d.from_name = 'God'
  d.delivery_method = :smtp
  d.server_host = "smtp.3dsmx.com" #    - The String hostname of the SMTP server (default: localhost).
  d.server_port = 25 #    - The Integer port of the SMTP server (default: 25).
  d.server_auth = false
end
# old
#God::Contacts::Email.message_settings = {
#  :from => 'god@agent5.3dsmx.com'
#}

# God::Contacts::Email.server_settings = {
#   :address => "smtp.3dsmx.com",
#   :port => 25,
#   :domain => "3dsmx.com"
#   :authentication => :plain,
#   :user_name => "john",
#   :password => "s3kr3ts"
# }

#God::Contacts::Email.server_settings = {
#  :address => "localhost",
#  :port => 25,
#  :domain => "3dsmx.com"
#}

contacts = %W{peter.scheer@amplixs.com eric.deruiter@amplixs.com bas.mesman@amplixs.com support@amplixs.com}
contacts.each do |contact|
  God.contact(:email) do |c|
    c.name = contact.split('@').first
    c.to_email = contact
  end
end