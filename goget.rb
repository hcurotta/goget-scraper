require 'rubygems'
require 'mechanize'
require 'csv'
require 'ruby-progressbar'


def login(agent)
	puts 'logging in...'

	login_page = agent.get('http://www.goget.com.au/bookings/login.php')

	account_page = login_page.form('Login') do |f|
	  f.vUser  = 'username'
	  f.vPwd   = 'password'
	end.click_button
end

def get_vehicles(agent)

	@vehicles = []

	progress = ProgressBar.create(:title => "Scraping", :starting_at => 0, :total => 1701, :format => '%t %c/%C items <%B> %p%%')

	(0..1700).each do |vehicle_id|
		vehicle = {}

		page = agent.get("http://www.goget.com.au/bookings/edit_entry.php?rt=1&room=#{vehicle_id}")
		vehicle[:vehicle_id] = vehicle_id
		vehicle[:vehicle_name] = page.parser.xpath("//option[@value='#{vehicle_id}']").text.split(' - ').first
		vehicle[:pod_name] = page.parser.xpath("//td[text()='Pod Name:']/following-sibling::td[1]").text
		vehicle[:area_id] = page.parser.xpath("//td[text()='Pod Name:']/following-sibling::td[1]/a").last.attributes["href"].value.split('=').last.to_i
		vehicle[:pod_id] = page.form('main')['pod'].to_i
		if vehicle[:vehicle_name] != nil
			vehicle[:vehicle_name].strip!
			vehicle[:vehicle_type] = page.parser.xpath("//option[@value='#{vehicle_id}']").text.split(' - ').first.split('the').last.strip
			@vehicles << vehicle
		end

		progress.increment
		

	end

	# CSV.open("vehicles.csv", "wb") do |csv|
	# 	csv << ["vehicle_id", "vehicle_name", "pod_name", "pod_id", "area_id"]
	# 	vehicles.each do |vehicle|
	# 		csv << [vehicle[:vehicle_id], vehicle[:vehicle_name], vehicle[:pod_name], vehicle[:pod_id], vehicle[:area_id]]
	# 	end
	# end

	# pods = CSV.read('pods.csv')
	# vehicles
end

def get_pods(agent)
	puts "processing locations..."

	page = agent.get('http://www.goget.com.au/bookings/show_location.php')

	raw = page.parser.xpath("//script").last.text

	declarations_reached = false

	current_index = 0

	@locations = []
	location = {}

	raw.each_line do |line|
		if line.start_with?("var point")
			# get the index from the end of the image_url0 set as current_index
			current_index = line.split('=').first.split('t').last.strip
			# get the lat
			location[:latitude] = line.split("(").last.split(")").first.split(", ").first
			#get the long
			location[:longitude] = line.split("(").last.split(")").first.split(", ").last
		end

		if line.start_with?("var info#{current_index}")
			location[:pod_id] = line.split('pod_id=').last.split(' ').first.to_i
			@locations << location
			location = {}
		end
	end
end




agent = Mechanize.new


login(agent)

get_vehicles(agent)

get_pods(agent)

results = []

@vehicles.each do |vehicle|
	@locations.each do |location|
		if vehicle[:pod_id] == location[:pod_id]
			results << {:vehicle_id 	=> vehicle[:vehicle_id],
									:vehicle_name => vehicle[:vehicle_name],
									:vehicle_type => vehicle[:vehicle_type],
									:pod_name 		=> vehicle[:pod_name],
									:latitude			=> location[:latitude],
									:longitude		=> location[:longitude],
									:area_id			=> vehicle[:area_id],
									:pod_id				=> vehicle[:pod_id]
								}
		end
	end
end

puts "writing csv..."

CSV.open("results.csv", "wb") do |csv|
	csv << ["vehicle_id", "vehicle_name", "vehicle_type", "pod_name", "pod_id", "area_id", "latitude", "longitude"]
	results.each do |vehicle|
		csv << [vehicle[:vehicle_id], vehicle[:vehicle_name], vehicle[:vehicle_type], vehicle[:pod_name], vehicle[:pod_id], vehicle[:area_id], vehicle[:latitude], vehicle[:longitude]]
	end
end

puts "DONE"