class SlackCommandParser
	attr_accessor :slack_user_id,:text, :toggl_account,:api_instance
  def command(params)
  	if !verify_token(params['token'])
  		return "Unverified client."
  	end
  	@text = params[:text]
  	@slack_user_id = params[:user_id]
  	parse
  end

  def parse
  	command = @text.partition(" ").first



  	if command != 'setup'
  		get_toggle_account
  	end

    tracker = Staccato.tracker(ENV['GA_ID'])
    tracker.event(category: 'command', action: command, label: @text)

  	case command
  	when 'setup'
  		parse_setup_command
  	when 'projects'
  		projects
  	when 'status'
  		status
  	when 'start'
  		start
  	when 'stop'
  		stop
  	else
  		"I don't know that command. :(. You can try the following commands  \n
        `/cheetah projects` \n
        `/cheetah status` \n
        `/cheetah start <project id> <optional description>` \n
        `/cheetah stop` \n
      "
    end
  end

  def check_if_good_to_go user_id
    @slack_user_id = user_id
    get_toggle_account
    toggle_request.me
  end

  # /cheetah setup
  def parse_setup_command
   "Go to http://cheetah-track.herokuapp.com/slackinterface/setup?info=" << @slack_user_id << ' to connect Slack to your Toggl account.'
 end

 def projects
   response = ''
   toggle_request.my_projects.each do |p|
    response << p['name'] << " - " << p['id'].to_s << "\n"
  end
  response
end

  # /cheetah status
  def status
  	te = toggle_request.get_current_time_entry
  	if !te
  		return "Timer isn't currently active."
  	end


  	return getStatusText(te);

  end

  def getStatusText(time_entry) 
   if time_entry['duration'] > 0
    return_t = humanize time_entry['duration'] 
  else 
    return_t = humanize Time.new.to_i + time_entry['duration']
  end

  project = false
  if time_entry['pid']
    project = getProjectById(time_entry['pid'])
    return_t << ' - ' << project['name']
  end
  if time_entry['description']
    return_t << ' - ' << time_entry['description']
  end
  return return_t
end

  # /cheetah start <project id> <optional description>
  def start
  	project_id = @text.split[1]
  	if !project_id
  		return "Sorry! I need a project id or name. (`/cheetah start <project id or project name> <optional description>`)\n You can find one by using: `/cheetah projects`"
  	end
  	project = getProjectById(project_id)
  	if project == false
  		return "Couldn't find a project with an id or name`" << project_id << "`" 
  	end

  	description = @text.split[2..-1].join(' ')
  	if toggle_request.start_time_entry({'pid' => project['id'], 'description' => description})
  		return "Timers going!"
  	end

  	return "Something went wrong :/ Try again?"
  end

  def stop 
  	te = toggle_request.get_current_time_entry
  	if !te
  		return "Timer isn't currently active."
  	end

  	stop = toggle_request.stop_time_entry(te["id"])
  	"Timer stopped - " << getStatusText(stop)
  end

  def getProjectById pid
  	toggle_request.my_projects.each do |p|
  		if p['id'].to_s == pid.to_s
  			return p
  		end
      if p['name'].downcase == pid.to_s.downcase
        return p
      end
    end
    return false
  end


  def toggle_request
  	if @api_instance
  		return @api_instance
  	end
  	@api_instance = TogglV8::API.new(@toggl_account.api_token)
  	return @api_instance
  end

  def get_toggle_account
  	ta = TogglAccount.where(slack_user_id: @slack_user_id)
  	if ta.length == 0
  		return "Run `/cheetah setup before proceeding."
  	else
  		@toggl_account = ta.first
  	end
  end

  def humanize secs
   [[60, :seconds], [60, :minutes], [24, :hours], [1000, :days]].map{ |count, name|
     if secs > 0
       secs, n = secs.divmod(count)
       "#{n.to_i} #{name}"
     end
     }.compact.reverse.join(' ')
   end

   def verify_token token
    token == ENV['SLASH_COMMAND_TOKEN']
  end
end
