module("luci.controller.QS.QS", package.seeall)

require "luci.model.uci"

function index()
   local uci = luci.model.uci.cursor()
   require("luci.i18n").loadc("commotion")
   local i18n = luci.i18n.translate
   
   entry({"admin", "commotion", "QuickStartReset"}, call("reset"), i18n("Reset Commotion Quickstart"), 60)
   if uci:get('quickstart', 'options', 'complete') ~= 'true' then
	  entry({"QuickStart"}, call("main"), "Quick Start").dependent=false
   end
end


function reset()
   local uci = luci.model.uci.cursor()
   if luci.http.formvaluetable("reset") then
	  uci:set('quickstart', 'options', 'complete', 'false')
	  uci:save('quickstart')
	  uci:commit('quickstart')
	  main()
   else
	  luci.template.render("QS/main/Reset")
   end
end


function main()
	-- if return values get them and pass them to return value parser
	setFileHandler()
	if luci.http.formvalue then
	  errorMsg = checkPage()
	end
      --1) call uci parser, returning dict of pages
	local uci = luci.model.uci.cursor()
	local pageNo,lastPg = pages()
	--Create/clear a space for pageValues and populate with page
	local pageValues = {modules = {}, buttons = {}, page = {['pageNo'] = pageNo, ['lastPg'] = lastPg}}
	local pageContext = uci:get_all('quickstart', pageNo)
	-- iterate through the list of page content from the UCI file and run corresponding functions, populating a dictionary with the values required by each module
	local removeUpload = nil
	for i,x in pairs(pageContext) do
	   if i == 'modules' then
		  for _,z in ipairs(x) do
			 
			 pageValues.modules[z]=luci.controller.QS.QS[z .. "Renderer"]()
			 if type(pageValues.modules[z]) == 'table' and pageValues.modules[z]['upload'] then removeUpload = true end
		  end
	   elseif i == 'buttons' then
		  for _,z in ipairs(x) do
			 --Add buttons to page
			 pageValues.buttons[z]=true
		  end
	   else
		  pageValues[i]=x
	   end
	end
	if removeUpload == true and pageValues.modules.upload then
	   pageValues.modules.upload = nil
	end
	luci.template.render("QS/main/Quickstart", {pv=pageValues})
end

function pages()
   local uci = luci.model.uci.cursor()
   local pageNo = uci:get('quickstart', 'options', 'pageNo')
   local lastPg = uci:get('quickstart', 'options', 'lastPg')   
   return pageNo, lastPg
end

function logoRenderer()
   return 'true'
end

function checkPage()
   local returns = luci.http.formvalue()
   errors = parseSubmit(returns)
   return errors
end

function parseSubmit(returns)
	  --check for submission value
      local uci = luci.model.uci.cursor()
	  local submit = returns.submit
	  returns.submit = nil
	  if submit == 'next' then
		 local errors = {}
		 local modules = {}
		 for types,val in pairs(returns) do
			if types == 'moduleName' then
			   if type(val) == 'table' then
				  for _, value in ipairs(val) do
					 errors[value]= luci.controller.QS.QS[value .. "Parser"](returns)
				  end
			   else if type(val) == 'string' then
					 errors[val]= luci.controller.QS.QS[val .. "Parser"](returns)
					end
			   end
			end
		 end
		 log(errors)
		 if next(errors) == nil then
			page = uci:get('quickstart', 'options', 'pageNo')
			if tonumber(page) then
			   uci:set('quickstart', 'options', 'pageNo', page+1)
			else
			   nxtPg = uci:get('quickstart', page, 'nxtPg')
			   uci:set('quickstart', 'options', 'pageNo', nxtPg)
			end
			uci:set('quickstart', 'options', 'lastPg', page)
			uci:save('quickstart')
			uci:commit('quickstart')
		 else
			return(errors)
		 end
	  elseif submit == 'back' then
		 	page = uci:get('quickstart', 'options', 'pageNo')
			lastPg = uci:get('quickstart', 'options', 'lastPg')
			uci:set('quickstart', 'options', 'pageNo', lastPg)
			uci:set('quickstart', 'options', 'lastPg', 1)
			uci:save('quickstart')
			uci:commit('quickstart')
	  elseif submit ~= nil then
		 --parse button functions to be run
		 return luci.controller.QS.QS[submit .. "Button"]()
	  end
end


function welcomeRenderer()
   return 'true'
end

function welcomeParser()
   return nil
end

function basicInfoRenderer()
   --check current node_name and return it as nodename
   local uci = luci.model.uci.cursor()
   local changable = uci:get('nodeConf', 'confInfo', 'changableName')
   if changable == 'true' then
	  local nodeName = uci:get('nodeConf', 'confInfo', 'name')
	  if nodeName then
		 return {['name'] = nodeName}
	  end
   else
	  return {['name'] = 'static'}
   end
end

function basicInfoParser(val)
   local errors = {}
   local uci = luci.model.uci.cursor()
   if val.basicInfo_nodeName then
	  if val.basicInfo_nodeName == '' then
		 errors['node_name'] = "Please enter a node name"
	  else
		 uci:set('nodeConf', 'confInfo', 'name', val.basicInfo_nodeName)
		 uci:save('nodeConf')
		 uci:commit('nodeConf')
	  end
   end
   local p1 = val.basicInfo_pwd1
   local p2 = val.basicInfo_pwd2 
   if p1 or p2 then
	  if p1 == p2 then
		 if p1 == '' then
			errors['pw'] = "Please enter a password"
		 else   
			luci.sys.user.setpasswd("root", p1)
		 end
	  else
		 errors['pw'] = "Given password confirmation did not match, password not changed!"
	  end
   end
   if next(errors) == nil then
	  return nil
   else
	  return errors
   end
end

function nearbyMeshRenderer()
   local networks = commotionDaemon('nearbyNetworks')
   return networks
end

function nearbyMeshParser(val)
   if val.nearbyMesh then
	  log(val.nearbyMesh)
	  if luci.fs.isfile("/usr/share/commotion/configs/" .. val.nearbyMesh) then
		 log("WIN")
		 configFile = val.nearbyMesh
		 local returns = luci.sys.call("cp " .. "/usr/share/commotion/configs/" .. configFile .. " /etc/config/nodeConf")
		 if returns ~= 0 then
			error = "Error parsing config file. Please choose another config file or find and upload correct config" 
			return error 
		 end
	  else
		 commotionDaemon('apply', val.nearbyMesh)
		 --TODO find out what data Josh can pass me to build a nodeConf
		 --log('the daemon now passes me config data like magic and I place it in a nodeConf')
	  end
   else
	  error  = "Please choose a network if you would like to continue." 
	  return error 
   end
end

function oneClickRenderer()
   luci.sys.call("cp /usr/share/commotion/configs/Commotion /etc/config/nodeConf")
end

function uploadRenderer()
   local uci = luci.model.uci.cursor()
   local page = uci:get('quickstart', 'options', 'pageNo')
   local fileType = uci:get('quickstart', page, 'fileType')
   if fileType == 'config' then
   fileInstructions="and submit a config file from your own computer. You will be able to customize this configuration once it has been applied to the node."
   elseif fileType == 'key' then
	  fileInstructions="and submit a key file from your own computer. This will allow your node to talk to any network with the same key file"
   end   
   return {['fileType']=fileType, ['fileInstructions']=fileInstructions}
end

function uploadParser()
   local uci = luci.model.uci.cursor()
   if luci.http.formvalue("config") then
	  file = luci.http.formvalue("config")
   elseif luci.http.formvalue("key") then
	  file = luci.http.formvalue("key")
   end
   error = ''
   if file then
	  if luci.http.formvalue("config") then
		 if uci:get('nodeConf', 'confInfo', 'name') then
		 --check if a key is required in the conf and set next page to a key file uploader if it is.
			local confKeySum = uci:get('nodeConf', 'confInfo', 'key')
			log(string.len(confKeySum))
			if string.len(confKeySum) == 32 then
			   if luci.fs.isfile(keyLoc .. "network.keyring") then
				  local keyringSum = luci.sys.exec("md5sum " .. keyLoc .. "network.keyring" .. "| awk '{ print $1 }'")
				  if keyring ~= confKey then
					 currentNext = uci:get('quickstart', 'options', 'pageNo')
					 uci:set('quickstart', 'uploadKey', 'nextPg', currentNext)
					 uci:set('quickstart', 'options', 'pageNo', 'uploadKey')
					 uci:save('quickstart')
					 uci:commit('quickstart')
				  end
			   else
				  currentNext = uci:get('quickstart', 'options', 'pageNo')
				  uci:set('quickstart', 'uploadKey', 'nxtPg', currentNext)
				  uci:set('quickstart', 'options', 'pageNo', 'uploadKey')
				  uci:save('quickstart')
				  uci:commit('quickstart')
			   end
			end
		 else
			error = 'This file is not a configuration file. Please check the file and upload a working config file or go back and choose a pre-built config'
		 end
	  elseif luci.http.formvalue("key") then
		 --TODO swap out commented correct line for line below
		 if luci.sys.call("pwd") == '0' then
	   --if luci.sys.call("servald keyring list") == '0' then
			local confKeySum = uci:get('nodeConf', 'confInfo', 'key')
			if string.len(confKey) == 33 then
			   local keyringSum = luci.sys.exec("md5sum " .. keyLoc .. "network.keyring" .. "| awk '{ print $1 }'")
			   if keyring ~= confKey then
				  currentNext = uci:get('quickstart', 'options', 'pageNo')
				  uci:set('quickstart', 'uploadKey', 'nextPg', currentNext)
				  uci:set('quickstart', 'options', 'pageNo', uploadKey)
				  uci:save('quickstart')
				  uci:commit('quickstart')
			   end
			   --TODO swap out commented correct line for line below
			   elseif luci.sys.call("pwd") = '1' then
			 --elseif luci.sys.call("servald keyring list") == '1' then
			   error = 'The file uploaded is either not a proper keyring or has a pin that is required to access the key within. If you do not think that your keyring has a pin please upload a proper servald keyring for your network key. If your keyring is pin protected, please click continue below.'
			end
		 end
	  end
   end
   if error ~= '' then
	  return error
   end
end

function setFileHandler()
   local uci = luci.model.uci.cursor()
   local sys = require "luci.sys"
   local fs = require "luci.fs"
   local keyLoc = "/usr/share/serval/"
   local configLoc = '/etc/config/'
   -- causes media files to be uploaded to their namesake in the /tmp/ dir.
   local fp
   luci.http.setfilehandler(
	  function(meta, chunk, eof)
		 if not fp then
			if meta and meta.name == "config" then			   
			   fp = io.open(configLoc .. "nodeConf", "w")
			elseif meta and meta.name == "key" then
			   fp = io.open(keyLoc .. "network.keyring", "w")
			end
			if chunk then
			   fp:write(chunk)
			end
			if eof then
			   fp:close()
			end
		 end
	  end)
end


function configsRenderer()
--talk to daemon for configs
   local networks = commotionDaemon('configs')
   return networks
end

function configsParser()
   configFile = luci.http.formvalue("configFile")
   local returns = luci.sys.call("cp " .. "/usr/share/commotion/configs/" .. configFile .. " /etc/config/nodeConf")
   if returns ~= 0 then
	  return "Error parsing config file. Please choose another config file or find and upload correct config"
   end
end

function meshDefaultsRenderer()
   --set defaults with upload turned off by default
   defaults = {types = {}, upload = true, routing={}}
   local securityLanguage ={
	  "This network is insecure",
	  "This network is somewhat secure",
	  "This network is moderately secure",
	  "This network is secure against casual attackers",
	  "This network has adequate security for most needs"}

   local uci = luci.model.uci.cursor()
   --SECURITY 
   security = uci:get_list('nodeConf', 'defaults', 'sec')
   local secCounter = 0
   for _,x in ipairs(security) do
	  secCounter = secCounter +1
	  defaults.types[x] = uci:get('documentation', 'security', x)
   end
   defaults['secMsg'] = securityLanguage[secCounter/2]
   routing = uci:get('nodeConf', 'defaults', 'routing')
   defaults['routing'][routing] = uci:get('documentation', 'routing', 'OLSRd')
   
   --If an key is required add uploader
   if defaults.types['wpa_none'] then
	  defaults['upload'] = nil
	  defaults['uploadTitle'] = "a key for this network here"
   end
   return defaults
end

function meshDefaultsParser(val)
   --log(val)
end

function uploadConfButton()
   local uci = luci.model.uci.cursor()
   local page = uci:get('quickstart', 'options', 'pageNo')
   local lastPg = uci:get('quickstart', 'options', 'lastPg')
   uci:set('quickstart', 'options', 'lastPg', page)
   uci:set('quickstart', 'options', 'pageNo', 'uploadConf')
   uci:save('quickstart')
   uci:commit('quickstart')   
end

function preBuiltButton()
   local uci = luci.model.uci.cursor()
   local page = uci:get('quickstart', 'options', 'pageNo')
   local lastPg = uci:get('quickstart', 'options', 'lastPg')
   uci:set('quickstart', 'options', 'lastPg', page)
   uci:set('quickstart', 'options', 'pageNo', 'preBuilt')
   uci:save('quickstart')
   uci:commit('quickstart')
end

function oneClickButton()
   local uci = luci.model.uci.cursor()
   local page = uci:get('quickstart', 'options', 'pageNo')
   local lastPg = uci:get('quickstart', 'options', 'lastPg')
   uci:set('quickstart', 'options', 'lastPg', page)
   uci:set('quickstart', 'options', 'pageNo', 'oneClick')
   uci:save('quickstart')
   uci:commit('quickstart')
end
   

function connectedNodesRenderer()
   return nil
end

function connectedNodesParser()
   if luci.http.formvalue("key") then
	  file = luci.http.formvalue("key")
   end
end

function settingPrefsRenderer()
   local uci = luci.model.uci.cursor()
   commotionDaemon("engage")
   page = uci:get('quickstart', 'options', 'pageNo')
   if tonumber(page) then
	  uci:set('quickstart', 'options', 'pageNo', page+1)
   else
	  nxtPg = uci:get('quickstart', page, 'nxtPg')
	  uci:set('quickstart', 'options', 'pageNo', nxtPg)
   end
   uci:set('quickstart', 'options', 'lastPg', '1')
   uci:save('quickstart')
   uci:commit('quickstart')
   time = 120
   --TODO figure our where the daemon will pull the ssid from
   name = uci:get('nodeConf', 'confInfo', 'name')
   return {['time'] = time, ['name'] = name}
end

function sharingPrefsRenderer()
   local shareService = {}
   local uci = luci.model.uci.cursor()
   uci:foreach("quickstart", "sharing",
			   function(s)
				  table.insert(share_service,{svc_name=s.name, svc_value=s.value, svc_description=s.description, svc_help=s.help})
			   end)
   return shareService
end

function sharingPrefsParser()
   local uci = luci.model.uci.cursor()
   errors = {}
   if luci.http.formvaluetable("share") then
	  sharing_prefs = luci.http.formvaluetable("share")
	  for option, id in pairs(sharing_prefs) do
		 --ACCESS POINT
		 if id == "pap" then
			if luci.http.formvaluetable("pap") then
			   accessPoint =  luci.http.formvaluetable("pap")
			end
			if accessPoint then
			   uci:set('nodeConf', 'sharingPrefs', 'ap', accessPoint.name) 
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
					 errors['sap'] = "Please enter a password"
				  elseif secAccessPoint then
					 uci:set('nodeConf', 'sharingPrefs', 'sapName', accessPoint.name)
					 uci:set('nodeConf', 'sharingPrefs', 'sapPW', p1) 
				  end	  
			   else
				  errors['sap'] = "Given password confirmation did not match, password not changed!"
			   end
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
			   errors['cptv'] = "Please fill out text for your captive portal."
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
			uci:set('nodeConf', 'sharingPrefs', 'gateway', 'true')
			--This will turn off olsrd_dyn_gw.so.0.5
		 end
		 if gateway ~= true then
			uci:set('nodeConf', 'sharingPrefs', 'gateway', 'false')
		 end
		 uci:save('nodeConf')
		 uci:commit('nodeConf')
		 --APPLICATIONS
		 if id == "apps" then
			if luci.http.formvalue("app.type") then
			   types = {}
			   appType = luci.http.formvalue("app.type")
			   for _,x in ipairs(appType) do
				  table.insert(types, x) 
			   end
			   uci:set_list('applications', 'settings', 'category', types)
			else
			   errors["apps"] = "Please add some application categories if you would like an application portal."
			end
			if luci.http.formvalue("app.minutes") then
			   appMin = luci.http.formvalue("app.minutes")
			   appMin = appMin/60
			   uci:set('applications', 'settings', 'expiration', appMin)
			else
			   errors["apps"] = "Please pick a ammount of time for apps to last. May I suggest 60?"
			end
			--TODO add app.renew, app.approve, and app.connectivity checks HERE
			uci:save('applications')
			uci:commit('applications')
		 end
		 
		 --Create A new Network
		 if id == "new" then
			if luci.http.formvaluetable("new") then
			   newNetwork =  luci.http.formvaluetable("new")
			   uci:set('nodeConf', 'sharingPrefs', 'meshSSID', newNetwork.ssid)
			   
			   hex = {1,2,3,4,5,6,7,8,9,0,'A','B','C','D','E','F'}
			   MAC = "00:00:00:00:00:00"
			   newBSSID = ""
			   for w in string.gmatch(MAC, ".") do
				  if w == ":" then
					 newBSSID = newBSSID .. w
				  else d = hex[math.random(16)]
					 newBSSID = newBSSID .. d
				  end
			   end
			   uci:set('nodeConf', 'sharingPrefs', 'meshBSSID', newBSSID)
			   uci:save('nodeConf')
			   uci:commit('nodeConf')
			end
		 end
	  end	 
   end
   if next(errors) == nil then
	  return nil
   else
	  return errors
   end
end


function completeRenderer()
   local uci = luci.model.uci.cursor()
   uci:set('quickstart', 'options', 'complete', 'true')
   uci:save('quickstart')
   uci:commit('quickstart')
   luci.http.redirect("/cgi-bin/luci/admin")
   do return end
end

function connectedNodesRenderer()
   return nil
end

function connectedNodesParser()
end

function commotionDaemon(request, value)
--TODO have this function make Ubus calls to the commotion daemon instead of pass back dummy variables
--This if statement FAKES grabbing nearby mesh networks from the commotion daemon
   errors = {}
   --TODO UBUS uncomment
   --load ubus module
   if request == 'nearbyNetworks' then
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
	  return networks
   elseif request == 'configs' then
	  local networks = {
		 { name="Commotion", config="This is the commotion network"},
		 { name="RedHooks", config="Tidepool Pride WHAZZAP"},
		 { name="Ninux", config="This is teh Ninux network"},
		 { name="Byzantium", config="Byzantine network"},
		 { name="Funkfeuer", config="DAS da commotion network"},
		 { name="FreiFunk", config="This esta  the commotion network"},
		 { name="Big Bobs Mesh Network", config="This is noda the commotion network"},
		 { name="Viva la' Revolution", config="This is not the commotion network"},
	  }
	  return networks
   elseif request == 'I NEED A CONFIG JOSH' then
	  return nil
   elseif request ='engage' then
	  --TODO incorporate the final ubus add/select sections ehre
	  end
   end
end




















function log(msg)
   if (type(msg) == "table") then
	  for key, val in pairs(msg) do
		 if type(key) == 'boolean' then
			log('{')
			log(tostring(key))
			log(':')
			log(val)
			log('}')
		 elseif type(val) == 'boolean' then
			log('{')
			log(key)
			log(':')
			log(tostring(val))
			log('}')
		 else
			log('{')
			log(key)
			log(':')
			log(val)
			log('}')
		 end
	  end
   else
	  luci.sys.exec("logger -t luci " .. msg)
   end
end