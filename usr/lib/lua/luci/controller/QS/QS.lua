--[[

Commotion QuickStart - LuCI based Application Front end.
Copyright (C) <2012>  <Seamus Tuohy>

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]--

module("luci.controller.QS.QS", package.seeall)


require "luci.model.uci"

function index()
	local uci = luci.model.uci.cursor()
	--checks quickstart uci to disallow quickstart once completed
	--QS does not require admin and has too much power to be accessable through a portal
	if uci:get('quickstart', 'options', 'complete') ~= 'true' then
	--each page gets an entry that either calls a template or a function
	--any function call needs a template call at the end of the function

	entry({"QS", "start"}, call("start"), "Quick Start").dependent=false
	entry({"QS", "welcome"}, template("QS/main/QS_welcome"), "Quick Start").dependent=false
	entry({"QS", "basicInfo"}, call("basic_info")).dependent=false
	entry({"QS", "nearbyMesh"}, call("find_nearby")).dependent=false
	entry({"QS", "sharingPrefs"}, call("sharing_options")).dependent=false
	entry({"QS", "sharingPrefs", "set"}, call("set_sharing_options")).dependent=false
	entry({"QS", "chosenMeshDefault"}, call("mesh_defaults")).dependent=false
	entry({"QS", "connectedNodes"}, call("connected_nodes")).dependent=false
	entry({"QS", "bugReport"}, call("bug_report")).dependent=false
	entry({"QS", "downloader"}, call("download_file")).dependent=false
	entry({"QS", "uci"}, call("uci_loader")).dependent=false
	entry({"QS", "uci", "submit"}, call("set_uci")).dependent=false	
	entry({"QS", "chooseConfig"}, call("choose_config")).dependent=false
	entry({"QS", "complete"}, call("complete")).dependent=false
	entry({"QS", "tryNetwork"}, call("set_config")).dependent=false
	entry({"QS", "upload"}, call("upload_file")).dependent=false
		  
	--Pages that have upload buttons on them 
	entry({"QS", "uploadConfig"}, call("upload_file", "QS_uploadConfig")).dependent=false
	--entry({"QS", "sharingPrefs", "upload"}, call("upload_file", "sharingPrefs")).dependent=false
	--entry({"QS", "chosenMeshConfig", "upload"}, call("upload_file2")).dependent=false
	--template page to change the start page TO REMOVE BEFORE DEPLOYMENT
    --entry({"QS", "changeStart"}, call("start", "nearbyMesh")).dependent=false

	--a testing function TO BE REMOVED BEFORE DEPLOYMENT
	entry({"QS", "test"}, call("test")).dependent=false
end
end

--TODO  TO BE TAKEN OUT BEFORE DEPLOYMENT
function test()
		 error("666")
end

function log(msg)
   if (type(msg) == "table") then
	  for key, val in pairs(msg) do
		 log('{')
		 log(key)
		 log(':')
		 log(val)
		 log('}')
	  end
   else
	  luci.sys.exec("logger -t luci " .. msg)
   end
end
--REMOVE ALL OF THE ABOVE BEFORE DEPLOYMENT OR FACE MY WRATH

function download_file()
	local result = luci.http.formvalue
	local filetype = result("type")
	local id = result("id")
	local contents = ""
	if result("download") and result("filename") then
	   local fp = io.open(result("filename"), "r")
	   if (fp) then
	   	  log("Opened the file!")
		  luci.http.prepare_content("application/force-download")
		  luci.http.header("Content-Disposition", "attachment; filename=" .. result("filename"))
		  e, es = luci.ltn12.pump.all(luci.ltn12.source.file(fp), luci.http.write)
		  log("es: " .. es)
		  fp:close()
	end
	elseif id and filetype then
		local uci = luci.model.uci.cursor()
		local filename
		if filetype == "error" then
		   	  filename = uci:get('quickstart', 'errors', id)
		elseif filetype == "config" then
		      filename = uci:get('quickstart', 'configs', id)
		end
		if filename then
		   local fp = io.open(filename, "r")
		   if fp then
		   	  local string = fp:read("*a")
			  while string ~= "" do
			  		contents = contents .. string
					string = fp:read("*a")
			  end
		   fp:close()
		   end
		end
		luci.template.render("QS/main/QS_downloader", {filename=filename, contents=contents})
	else
		luci.template.render("QS/main/QS_downloader", {})
	end
end

function start(x)
	local uci = luci.model.uci.cursor()
         local startPage = ''
  	  	 if x then
		 	uci:set('quickstart', 'options', 'startpage', x)
		 	uci:save('quickstart')
		    uci:commit('quickstart')
			startPage = x
		 else
			startPage = uci:get('quickstart', 'options', 'startpage')
			luci.http.redirect(startPage)
		 end
end


function complete()
	local uci = luci.model.uci.cursor()
	uci:set('quickstart', 'options', 'complete', 'true')
	uci:save('quickstart')
	uci:commit('quickstart')
	luci.template.render("QS/main/QS_finished")
end


function error(errorNo)
--This should be called when the daemon returns a error, and passed the error number
	local uci = luci.model.uci.cursor()
	errorMsg = uci:get('QS_error', errorNo, 'errorMsg')
	errorLoc = uci:get('QS_error', errorNo, 'errorLoc')
	errorDesc = uci:get('QS_error', errorNo, 'errorDesc')

	if errorMsg and errorLoc and errorDesc and errorNo then
	   luci.template.render("QS/main/QS_errorPage", {errorMsg=errorMsg, errorLoc=errorLoc, errorDesc=errorDesc, errorNo=errorNo})
	else
		luci.template.render("QS/main/QS_errorPage", {})
	end
end


function basic_info()
		if luci.http.formvalue("node_name") then
		    local uci = luci.model.uci.cursor()
			local node_name = luci.http.formvalue("node_name")
			if node_name == '' then
			   message = "Please enter a node name"
			   luci.template.render("QS/main/QS_basicInfo", {message=message})
			else
			   uci:set('quickstart', 'options', 'name', node_name)
		 	   uci:save('quickstart')
		       uci:commit('quickstart')
		 	   local p1 = luci.http.formvalue("pwd1")
	    	   local p2 = luci.http.formvalue("pwd2")
				  if p1 or p2 then
				  	 if p1 == p2 then
					 	if p1 == '' then
						   message = "Please enter a password"
						   luci.template.render("QS/main/QS_basicInfo", {message=message, current=node_name})
						else   
					        luci.sys.user.setpasswd("root", p1)
			 			    luci.http.redirect("nearbyMesh")
						end
					 else
					    message = "Given password confirmation did not match, password not changed!"
						luci.template.render("QS/main/QS_basicInfo", {message=message, current=node_name})
					 end
				else
				luci.http.redirect("nearbyMesh")
				end
			end
		else
			luci.template.render("QS/main/QS_basicInfo")
		end
end


function find_nearby()
		 --TODO : this would eventually call the daemon. For now we just send some falsified data over.
		 local networks = {
		 	   { name="Commotion", config="true"},
		 	   { name="RedHooks", config="true"},
		 	   { name="Ninux", config="false"},
		 	   { name="Byzantium", config="true"},
		 	   { name="Funkfeuer", config="false"},
		 	   { name="FreiFunk", config="false"},
		 	   { name="Big Bobs Mesh Network", config="false"},
		 	   { name="Viva la' Revolution", config="true"},
		}
		
		luci.template.render("QS/main/QS_nearbyMesh", {networks=networks, test=test})
end

function set_sharing_options()
   --TODO: Create a switch that parses the svc_name and runs a function if the value passed to this function has clicked/unclicked checkboxes.

   local uci = luci.model.uci.cursor()   
   if luci.http.formvaluetable("share") then
	  sharing_prefs = luci.http.formvaluetable("share")
	  log(sharing_prefs)
	  for option, id in pairs(sharing_prefs) do
		 --ACCESS POINT
		 log(id)
		 if id == "pap" then
			if luci.http.formvaluetable("pap") then
			   accessPoint =  luci.http.formvaluetable("pap")
			end
			if accessPoint then
			   uci:foreach("wireless", "wifi-iface",
						   function(s)
							  if s.mode == "ap" and not s.encryption then
								 apExist = true
							  end
							  if apExist == true then
								 setAP = false
								 if s.mode == "ap" and s.ssid ~= accessPoint.name then
									uci:set("wireless", s['.name'], "ssid", accessPoint.name)
								 end
							  end
						   end)
			   if apExist ~= true then
				  local values = {
					 ['network'] =  "ap",
					 ['mode'] =  "ap",
					 -- TODO How do we determine the radio? is there a better way
					 ['device'] =  "radio0",
					 ['ssid'] =  accessPoint.name,
				  }
				  uci:section('wireless', 'wifi-iface', null, values)
			   end
			   uci:save('wireless')
			   uci:commit('wireless')
			end
		 end
		 
		 --SECURE ACCESS POINT
		 if id == "sap" then
			if luci.http.formvaluetable("sap") then
			   secAccessPoint =  luci.http.formvaluetable("sap")
			end
			p1 = secAccessPoint.pwd1
			p2 = secAccessPoint.pwd2
			if p1 or p2 then
			   if p1 == p2 then
				  if p1 == '' then
					 message = "Please enter a password"
					 luci.template.render("QS/main/QS_sharingPrefs", {message=message})
				  else   
					 if secAccessPoint then
						uci:foreach("wireless", "wifi-iface",
									function(s)
									   if s.mode == "ap" and s.encryption then
										  sapExist = true
									   end
									   if sapExist == true then
										  uci:set("wireless", s['.name'], "ssid", secAccessPoint.name)
										  uci:set("wireless", s['.name'], "key", p1)
									   end
									end)
						if sapExist ~= true then
						   local values = {
							  ['network'] =  "ap",
							  ['mode'] =  "ap",
							  -- TODO How do we determine the radio? is there a better way
							  ['device'] =  "radio0",
							  ['encryption'] = "psk2",
							  ['key'] = p1,
							  ['ssid'] =  secAccessPoint.name,
						   }
						   uci:section('wireless', 'wifi-iface', null, values)
						end
						uci:save('wireless')
						uci:commit('wireless')
					 end
					 message = "password SUCCESS"
					 luci.template.render("QS/main/QS_sharingPrefs", {message=message})
				  end
			   else
				  message = "Given password confirmation did not match, password not changed!"
				  luci.template.render("QS/main/QS_sharingPrefs", {message=message})
			   end
			end
		 end
		 
		 
		 --NETWORK KEY UPLOADER
		 if id == "key" then
			if luci.http.formvalue("file") then
			   upload(null)
			end
		 end
		 
		 --CAPTIVE PORTAL
		 if id == "cptv" then
			if luci.http.formvaluetable("cptv") then
			   captive =  luci.http.formvaluetable("cptv")
			end
			local fs = require "nixio.fs"
			local splashtextfile = "/www/splash.htm"
			--TODO change splashtext file to below...
			--local splashtextfile = "/usr/lib/luci-splash/splashtext.html"
			for i,x in pairs(captive) do
			   if i == "main" then
				  if x == "" then
					 main = ""
				  else
					 main = ("<p>" .. x .. "</p>")
				  end
			   elseif i == "title" then
				  if x == "" then
					 title = ""
				  else
					 title = ("<h1>" .. x .. "</h1>")
				  end
			   elseif i == "home" then
				  uci_values = 1
				  uci:set('luci_splash', 'general', 'homepage', x)
			   elseif i == "time" then
				  uci_values = 1
				  uci:set('luci_splash', 'general', 'leasetime', x) 				  
			   end
			end
			data = (title .. main)
			if data == "" then
			   message = "Please fill out text for your captive portal."
			   luci.template.render("QS/main/QS_sharingPrefs", {message=message})
			   fs.unlink(splashtextfile)
			else
			   fs.writefile(splashtextfile, data:gsub("\r\n", "\n"))
			end
			if uci_values then
			   uci:save('luci_splash')
			   uci:commit('luci_splash')
			end
		 end
		 --GATEWAY 
		 if id == "gate" then
			gateway = true
			uci:foreach("olsrd", "LoadPlugin",
						function(s)
						   if s.library == "olsrd_dyn_gw.so.0.5" then
							  dyn_gw = true
						   end
						   if dyn_gw ~= true then
							  uci:section("olsrd", "LoadPlugin", null,  {['library'] =  "olsrd_dyn_gw.so.0.5"})
							  uci:save('olsrd')
							  uci:commit('olsrd')
						   end
						end)
		 end
	  end
   end
   if gateway ~= true then
	  uci:foreach("olsrd", "LoadPlugin",
				  function(s)
					 if s.library == "olsrd_dyn_gw.so.0.5" then
						dyn_gw = true
					 end
					 if dyn_gw == true then
						uci:delete("olsrd", s['.name'])
						uci:save('olsrd')
						uci:commit('olsrd')
					 end
				  end)
   end	 
   complete()
end

function sharing_options()
--This grabs the shared services from the quickstart uci page
   local share_service = {}
   local uci = luci.model.uci.cursor()
   uci:foreach("quickstart", "sharing",
			   function(s)
				  table.insert(share_service,{svc_name=s.name, svc_value=s.value, svc_description=s.description, svc_help=s.help})
			   end)
   
   
   luci.template.render("QS/main/QS_sharingPrefs", {share_service=share_service})
end


function switch(t,x,y)
   t.case = function (self,x,y)
      local f=self[x] or self.default
	  if f then
	  	 if type(f)=="function" then
		 	f(x,self,y)
		 else
			error("case "..tostring(x).." not a function")
		 end
	  end
   end
   return t
end

function mesh_defaults(config, keyval)
   -- This config value is the name of the config file to be passed to the daemon later to grab configs, etc.
   -- we check to see if passed via function, and if not then via GET request
   if not config then
	  config = luci.http.formvalue("config")
   end
   --TODO Later this will parse text from each config file and then use that data against a set of values here to create a "network defaults" info page.
   
   local security_counter = 0
   local list_items = {}
   
   -- parse config of network/ call daemon for network values
   -- TODO FIX values below are temporary fakes
   network = config
   local defaults = {
	  OLSR_secure = true,
	  WPA_None = true,
	  ServalD = true,
	  DTN = true,
	  network_key = "HASHVALUEov0984jvdef",
	  gateway_sharing = true,
	  app_sharing = true,
   }
   --end of fakes
   
   
   --Create switch to parse through for values (still need full list)
   default_switch = switch {
	  OLSR_secure = function (x,y,value) if value == true then results={"sec",1} return results end end,
		 WPA_None = function (x,y,value)  if value == true then results={"sec",1}  return results end end,
			ServalD = function (x,y,value)  if value == true then results = {"sec",1} return results end end,
			   DTN = function (x,y,value)  if value == true then results = {"sec",1} return results end end,
				  network_key = function (x,y,value) if value then results = {"network_key",value} return results end end,
					 gateway_sharing = function (x,y,value) if value then results = {"gateway_sharing",value} return results end end,
						app_sharing = function (x,y,value) if value then results = {"app_sharing",value} return results end end,
						   }
   
   for i, value in pairs(defaults) do
	  default_switch:case(i, value)
	  if results[1] == "sec" then
		 security_counter = security_counter + results[2]
	  else
		 table.insert(list_items,{results[1],results[2]})
	  end
	  results = {}
   end
   table.insert(list_items,{"security_counter",security_counter})
   
   --If a key is uploaded send it back with the uploaded key values.
   if keyval then
	  defaults.network_key = keyval
   end
   
   --send list of items to the template for parsing
   luci.template.render("QS/main/QS_chosenMeshDefault", {list_items=list_items, network=network})
end

function upload_file(page, value)
   --TODO File handler does not work... WH please fix :)
   log("upload_file")
   local sys = require "luci.sys"
   local fs = require "luci.fs"
   local tmp = "/tmp/"
   -- causes media files to be uploaded to their namesake in the /tmp/ dir.
   local fp
   luci.http.setfilehandler(
	  function(meta, chunk, eof)
		 log("function starts")
		 if not fp then
			log("if not fp starts")
			if meta and meta.name == "config" then
			   log("config")
			   fp = io.open(tmp .. meta.file, "w")
			   mesh_defaults(meta.file)
			elseif meta and meta.name == "key" then
			   log("key")
			   fp = io.open(tmp .. meta.file, "w")
			   --create hash of key
			   --check key hash against hash of key in config
			   --send result "false" or "correct" back to mesh_defaults with mesh_defaults(config, keyval)
			end
			if chunk then
			   log("if chunk")
			   fp:write(chunk)
			end
			if eof then
			   log("if eof")
			   fp:close()
			end
		 end
	  end)
   if luci.http.formvalue("config") then
	  file = luci.http.formvalue("config")
	  --log(file)
   end
   
   if luci.http.formvalue("page") then
	  page = luci.http.formvalue("page")
   end
   if page ~= null then
	  log(page)
	  if file ~= null then
		 luci.http.redirect(page .. "?config=" .. file)
	  else
		 luci.template.render("QS/main/" .. page, {value=value})
	  end
   else
	  next = luci.http.formvalue("next")
	  luci.http.redirect(next)
   end
end


function set_config(config)
   if not config then
	  config = luci.http.formvalue("config")
   end
   --TODO remove the following if statement that shows both conditions. Keep the "result =" as stated in later comments
   if config == "Big Bobs Mesh Network" then
	  result = 666
   else
	  --TODO Send the name of the config file to the daemon and have it set those configurations.
	  --TODO change "sleep" in next line to commotion_daemon call w/ config
	  result = luci.sys.call("sleep 1")
   end
   if result == 0 then
	  wait_4_reset("connectedNodes", "Your configurations have been set")
   else
	  error(result)
   end
end

function wait_4_reset(page, notice)
   --TODO add the wait_4_reset function to all pages that have setting changes that require reset.
   local uci = luci.model.uci.cursor()
   --make the node name unique for restart
   local name = uci:get('quickstart', 'options', 'name')
   
   UName = name .. "_" .. luci.sys.uniqueid(5)
   uci:foreach("wireless", "wifi-iface",
			   function(s)
				  if s.mode == "ap" then
					 --save the correct AP if it has not already been set
					 if not uci:get('quickstart', 'options', 'APname') then
						uci:set("quickstart", "options", "APname", s.ssid)
						uci:save('quickstart')
						uci:commit('quickstart')
					 end
					 --set the unique AP for next reset
					 uci:set("wireless", s['.name'], "ssid", UName)
					 uci:save('wireless')
					 uci:commit('wireless')
				  end
			   end)
   
   --set the new start page
   start(page)
   timer = 120
   luci.template.render("QS/main/QS_wait4reset", {timer=timer, name=UName, notice=notice})
   luci.sys.reboot()
end

function uci_loader(message)
   if luci.http.formvalue("module") then
	  template = luci.http.formvalue("module")
   else template = "QS_uci"
   end
   if message == null then
	  uci_page = luci.http.formvalue("uci")
	  uci_last_page = luci.http.formvalue("last")
   else
	  uci_page = luci.http.formvalue("last")
   end
   if uci_page == "finish" then
	  sharing_options()
	  do return end
   end
   local documentation = {}
   local settings = {}
   local uci = luci.model.uci.cursor()
   uci:foreach("QS_documentation", "documentation",
			   function(s)
				  if s.section == uci_page then
					 if s.title == "settings" then
						page_instructions = s.page_instructions
						next_page = s.next_page
						uci_header = s.header
					 elseif s.title ~= "settings" then
						table.insert(documentation,s)
					 end end end)
   
   luci.template.render("QS/main/" .. template, {message=message, uci_header=uci_header, uci_page=uci_page, page_instructions=page_instructions, uci_last_page=uci_last_page, next_page=next_page, documentation=documentation})
end


function set_uci()
   local uci = luci.model.uci.cursor()
   message = null
   uci_values = luci.http.formvaluetable("uci")
   for i,value in pairs(uci_values) do
	  if value ~= "" then
		 ret = uci_call(i, value)
		 if ret ~= 0 then
			message = ret
		 end
		 luci.sys.call("sleep 1")
	  end 
   end
   uci_loader(message)
end

function uci_call(type, value)
   local uci = luci.model.uci.cursor()
   --Set AP SSID
   if type == "SSID_AP" then
	  --Parse value and set message to return if not correct format
	  uci:foreach("wireless", "wifi-iface",
				  function(s)
					 if s.mode == "ap" and s.ssid ~= value then
						uci:set("wireless", s['.name'], "ssid", value)
						uci:save('wireless')
						uci:commit('wireless')
					 end
				  end)
	  --Set Mesh SSID
   elseif type == "SSID_MESH" then
	  --Parse value and set message to return if not correct format
	  uci:foreach("wireless", "wifi-iface",
				  function(s)
					 if s.mode == "adhoc" and s.ssid ~= value then
						uci:set("wireless", s['.name'], "ssid", value)
						uci:save('wireless')
						uci:commit('wireless')
					 end
				  end)
	  --Set Mesh BSSID
   elseif type == "BSSID_MESH" then
	  --Parse value and set message to return if not correct format
	  uci:foreach("wireless", "wifi-iface",
				  function(s)
					 if s.mode == "adhoc" and s.bssid ~= value then
						uci:set("wireless", s['.name'], "bssid", value)
						uci:save('wireless')
						uci:commit('wireless')
					 end
				  end)
   else
	  return "UCI option " .. type .. " not implemented"
   end
   return 0
end

function connected_nodes()
   --TODO this is mostly stolen from olsrd.lua. Just need to parse the file to get the number of neighbors
   -- TODO switch this rawdata call out with one below
   --local rawdata = luci.sys.httpget("http://127.0.0.1:2006/neighbors")
   --TODO remove the false raw data below and implement the one above... just like the other comment says.
   local rawdata =[[Table: Neighbors
IP address		SYM		MPR		MPRS	Will.	2 Hop Neighbors
10.10.0.152		YES		NO		NO		6		0
5.10.0.152		YES		NO		NO		6		34
10.2.0.152		YES		NO		NO		6		1
10.10.0.142		YES		NO		NO		6		5]]
local tables = luci.util.split(luci.util.trim(rawdata), nil, nil, nil)
neighbors = 0
for i,x in ipairs(tables) do
   if string.find(x, "^%d+%.%d+%.%d+%.%d+") then
	  neighbors = neighbors + 1
   elseif string.find(x, "^%x+%:%x+%:%x+%:%x+%:%x+%:%x+%:%x+%:%x+") then
		 neighbors = neighbors + 1
   end
end

   luci.template.render("QS/main/QS_connectedNodes", {neighbors=neighbors})
end


function choose_config()
   --TODO : this would eventually call the daemon to check the hardware and provide the appropriate mesh configs. For now we just send some falsified data over.
   local configs = {
	  { name="Commotion", type="AwesomeSauce"},
	  { name="RedHooks", type="Community epicness"},
	  { name="Ninux", type="Italian?"},
	  { name="Byzantium", type="Laptop-ness"},
	  { name="Funkfeuer", type="Austrian"},
	  { name="FreiFunk", type="C base 4TheWin"},
	  { name="Big Bobs Mesh Network", type="With all the trappings"},
	  { name="Viva la' Education", type="We dont need no"},
   }
   
   luci.template.render("QS/main/QS_chooseConfig", {configs=configs})
end