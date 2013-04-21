#Goget's car search sucks. 

They have a map which shows current availability for all cars, but you can't see what kind of car it is. So you have to go into the bookings interface and search near an address. When you search here, you can see only a list of cars and addresses. The only map is the size of a postage stamp and doesnt show much at all. You are left searching all over the place if you want particular vehicle type (e.g. a van or a ute). 

I resolved to get all the data on a big google map and let people browse from there.

First I needed to get a list of every pod (car space) they have, and the lat and long so I can map them. They already use google maps on their site, so I figured that would expose some URI endpoint for serving up lists of pods with their current booked/unbooked status.

After digging around for a bit, I found that rather than fetching pods dynamically, goget renders details of every single pod in the country in a javascript file... so it declares about 3000 variables...yep. for instance:

```javascript
var image_url0="http://www.goget.com.au/bookings//secret/plugins/available_now_plugin/icons/arrow_green.gif";
var point0 = new google.maps.LatLng(-33.899, 151.183);
var info0 = "<iframe frameborder=0 scrolling=auto height=150 width=100% src=http://www.goget.com.au/bookings/locations/podPopup.php?pod_id=2 width=100%></iframe>";
createPod(point0, info0,image_url0);

var image_url1="http://www.goget.com.au/bookings//secret/plugins/available_now_plugin/icons/arrow_green.gif";
var point1 = new google.maps.LatLng(-33.8939, 151.1776);
var info1 = "<iframe frameborder=0 scrolling=auto height=150 width=100% src=http://www.goget.com.au/bookings/locations/podPopup.php?pod_id=4 width=100%></iframe>";
createPod(point1, info1,image_url1);
```
...and so on for all 1000 odd pods

I'll write a script to parse that later.

So now I have a location for every pod but I don't know what vehicle resides in each pod. There doesn't seem to be an easy way to make the association between pod and vehicle. 

From digging about in the bookings area, it seems like vehicle id == room number in the query string params (are they actually using a room bookings system for the cars?)

This means the vehicle shown here

http://www.goget.com.au/bookings/show_vehicle.php?vehicle_id=200

Is bookable here

http://www.goget.com.au/bookings/edit_entry.php?rt=1&room=200

Looks like the bookings page has all i need in the form. There's a hidden field in there with the pod_id and the vehicle_id is also shown. This is gives me my join. It also gives me some handy stuff like the name of the vehicle and pod. All I have to do is load that page up about 1700 times to get info for all the cars, iterating on the vehicle/room id.

Mechanize is a great Gem that allows you to interact with html pages and perform actions. First I'll need to login

```ruby

require 'mechanize'

def login(agent)
	puts 'logging in...'

	login_page = agent.get('http://www.goget.com.au/bookings/login.php')

	account_page = login_page.form('Login') do |f|
	  f.vUser  = 'username'
	  f.vPwd   = 'password'
	end.click_button
end

agent = Mechanize.new
login(agent)

```

Now I can call up the bookings page where all the vehicle info lives...

```ruby
page = agent.get("http://www.goget.com.au/bookings/edit_entry.php?rt=1&room=#{vehicle_id}")

```

Mechanize lets me use xpath to parse the bookings page and find the elements I need. Some fairly rubbish string manipulation cleans it up.

```ruby
vehicle_name = page.parser.xpath("//option[@value='200']").text.split(' - ').first
vehicle_type = page.parser.xpath("//option[@value='#{vehicle_id}']").text.split(' - ').first.split('the').last.strip
pod_name = page.parser.xpath("//td[text()='Pod Name:']/following-sibling::td[1]").text
area_id = page.parser.xpath("//td[text()='Pod Name:']/following-sibling::td[1]/a").last.attributes["href"].value.split('=').last.to_i
pod_id = page.form('main')['pod'].to_i
```

I can loop through the above and increment the id each time to get info for each of the vehicles.

Awesome... so now I have all the data I need. All I have to do is throw both the location data and the vehicle data into some hashes and do a join on pod_id.

Then its onto some google maps JS fun.
