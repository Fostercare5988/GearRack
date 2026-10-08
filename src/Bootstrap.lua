-- GearRack. Engine extensions are DLLs, not addon Dependencies.
GearRack = {version="1.0.0", enabled=false}
local _,_,superMajor,superMinor=string.find(tostring(SUPERWOW_VERSION or ""),"^(%d+)%.(%d+)")
superMajor,superMinor=tonumber(superMajor),tonumber(superMinor)
local failure
if type(CLASSIC_API_VERSION)~="number" or CLASSIC_API_VERSION<11516 then
    failure="ClassicAPI 1.15.16 or newer"
elseif not superMajor or superMajor<2 or (superMajor==2 and superMinor<2) then
    failure="SuperWoW 2.2 or newer"
elseif type(GetNampowerVersion)~="function" then
    failure="NamPower 4.6.2 or newer"
else
    local major,minor,patch=GetNampowerVersion()
    if type(major)~="number" or type(minor)~="number" or type(patch)~="number" or
        not (major>4 or (major==4 and (minor>6 or (minor==6 and patch>=2)))) or
        type(GetCastInfo)~="function" or type(GetSpellIdCooldown)~="function" then
        failure="NamPower 4.6.2 or newer"
    end
end
if failure then
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff4040GearRack requires "..failure..". Load the required DLL and restart the client.|r",1,.25,.25)
    end
    return
end
GearRack.enabled=true
GearRack.Requests={}
GearRack.DirtyBags={}
GearRack.Items={}
GearRack.ByID={}
GearRack.ByName={}
GearRack.ByGUID={}
GearRackDB={bars={},settings={},events={},sets={},trinketOptions={}}
GearRackCharDB={trinkets={},queues={}}
