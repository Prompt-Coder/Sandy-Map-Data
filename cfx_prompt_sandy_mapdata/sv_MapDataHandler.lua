local maps = {
	"prompt_sandy_roads",
	"prompt_sandy_apts",
	"prompt_sandy_cityhall",
	"sandy_shores_houses_pt1",
	"prompt_sandy_beaches",
	"prompt_sandy_airfield"
}

local events = {}

-- Sandy mapdata exists event
RegisterNetEvent("prompt:mapdata_exists", function(cb)
  cb(true)
end)

-- Sandy mapdata list event
RegisterNetEvent("prompt:mapdata_sendList", function(returnevent)
  TriggerEvent(returnevent, maps)
end)

-- Legacy mapdata exists event
RegisterNetEvent("lyn-mapdata:exists", function(cb)
  cb(true)
end)

-- Legacy support for individual map checks
for i = 1, #maps do
  local eventName = maps[i] .. ":mapDataExists"
  if Debug == true then
    print("Creating event: ", eventName)
  end
  local event = RegisterNetEvent(eventName, function(cb)
    cb(true)
  end)
  table.insert(events, event)
end
