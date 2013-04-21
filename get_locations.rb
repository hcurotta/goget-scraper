require 'rubygems'
require 'mechanize'
require 'csv'


def login(agent)
	login_page = agent.get('http://www.goget.com.au/bookings/login.php')

	account_page = login_page.form('Login') do |f|
	  f.vUser  = '92504622'
	  f.vPwd   = '9978'
	end.click_button
end


agent = Mechanize.new

login(agent)

page = agent.get('http://www.goget.com.au/bookings/show_location.php')

raw = page.parser.xpath("//script").last.text

declarations_reached = false

current_index = 0

locations = []
location = {}

raw.each_line do |line|
	if line.start_with?("var point")
		# get the index from the end of the image_url0 set as current_index
		current_index = line.split('=').first.split('t').last.strip
		# get the lat
		location["latitiude_#{current_index}"] = line.split("(").last.split(")").first.split(", ").first
		#get the long
		location["longitude_#{current_index}"] = line.split("(").last.split(")").first.split(", ").last
	end

	if line.start_with?("var info#{current_index}")
		location["pod_id_#{current_index}"] = line.split('pod_id=').last.split(' ').first
		locations << location
		location = {}
	end
end

puts locations

CSV.open("pods.csv", "wb") do |csv|
	csv << ["pod_id", "longitude", "latitiude"]
	locations.each_with_index do |location, index|
		puts "pod_id_#{index}."
		puts location["pod_id_#{index}"]
		csv << [location["pod_id_#{index}"],location["longitude_#{index}"], location["latitiude_#{index}"]]
	end
end
