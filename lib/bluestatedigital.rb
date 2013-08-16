module BlueStateDigital
  ##
  # Accepts a hash of fields (firstname, lastname, city, state, zip, email) and
  # creates an email subscription in BSD Tools. The email and zip fields are
  # mandatory.
  # 
  # Returns a hash { :success => bool, :response => HTTParty::Response }
  def self.subscribe_to_email (subscribe_url, fields)
    allowed_params = ["email", "firstname", "lastname", "city", "state", "zip"]
    headers = {"Content-Type" => "application/x-www-form-urlencoded"}
    body = fields.select{|k,v| allowed_params.include? k.to_s }
    begin
      resp = HTTParty.post(subscribe_url, :body => body, :headers => headers, :no_follow => true)
    rescue HTTParty::RedirectionTooDeep => e
      resp = e.response
    end

    success = (resp.code == "302" && resp.body =~ /thanks/)
    { :success => success, :response => resp }
  end
end
