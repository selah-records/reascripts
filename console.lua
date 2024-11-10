---
---@module "console"
---
---
local path = ({ reaper.get_action_context() })[2]:match("^.+[\\//]")
dofile(path .. "lib.lua")

local Console = {}

local reaper = reaper

local console_allow_list = {
	"Console7Buss",
	"Console7Channel",
	"Console5Buss",
	"Console5Channel",
	"Console4Buss",
	"Console4Channel",
}

-- local console_plugins = {}
-- local plugins = List_au()
-- for _, plugin in pairs(plugins) do
-- 	if Contains(console_allow_list, plugin) then
-- 		-- if console_allow_list[plugin] ~= nil then
-- 		table.insert(console_plugins, plugin)
-- 	end
-- end
-- for _, plugin in pairs(console_plugins) do
-- 	reaper.ShowConsoleMsg(plugin .. "\n")
-- end

local console_channel = "Console7Channel"
local console_buss = "Console7Channel"

---@return table
function Get_tracks_routed_to_master()
	local tracks = {}
	for track_idx = 0, reaper.GetNumTracks() - 1 do
		local track = reaper.GetTrack(0, track_idx)
		if reaper.GetMediaTrackInfo_Value(track, "B_MAINSEND") == 1 then
			table.insert(tracks, track)
		end
	end
	return tracks
end

---@return Track, boolean, boolean
function Get_pfcb_sum_track()
	local hits = 0
	local sum_bus = nil
	for i = 0, reaper.GetNumTracks() - 1 do
		local track = reaper.GetTrack(0, i)
		local _, track_name = reaper.GetTrackName(track)

		if track_name == "PFCB_SUM" then
			hits = hits + 1
			sum_bus = track

			if reaper.GetMediaTrackInfo_Value(track, "B_MAINSEND") == 0 then
				reaper.ShowMessageBox(
					"Error: sum buss is not routed to master send. Sum bus must be routed to master send.\n",
					"Error",
					0
				)
				return nil, false, false
			end
		end
	end

	if hits == 0 then
		return nil, false, true
	end
	if hits > 1 then
		reaper.ShowMessageBox("Error: found " .. hits .. " sum busses! There should only be one.\n", "Error", 0)
		return nil, false, false
	end

	return sum_bus, true, true
end

---@param dest Track
---@return table
function Get_sends_to_dest(dest)
	local tracks = {}
	for i = 0, reaper.GetNumTracks() - 1 do
		local track = reaper.GetTrack(0, i)
		local num_sends = reaper.GetTrackNumSends(track, 0)
		for send_idx = 0, num_sends - 1 do
			if reaper.GetTrackSendInfo_Value(track, 0, send_idx, "P_DESTTRACK") == dest then
				table.insert(tracks, track)
			end
		end
	end
	return tracks
end

---@param track Track
---@return Track
function Create_pfcb(track, buss)
	local idx = Get_track_index(track)
	local _, name = reaper.GetTrackName(track)
	reaper.InsertTrackInProject(0, idx, 0)
	local dest = reaper.GetTrack(0, idx)
	reaper.SetMediaTrackInfo_Value(dest, "B_MAINSEND", 0)
	reaper.SetMediaTrackInfo_Value(dest, "B_SHOWINTCP", 0)
	reaper.SetMediaTrackInfo_Value(dest, "B_SHOWINMIXER", 0)
	reaper.GetSetMediaTrackInfo_String(dest, "P_NAME", name .. "_pfcb", true)
	local send = reaper.CreateTrackSend(track, dest)
	-- make send postfader
	reaper.SetTrackSendInfo_Value(track, 0, send, "I_SENDMODE", 0)
	send = reaper.CreateTrackSend(dest, buss)
	reaper.SetTrackSendInfo_Value(track, 0, send, "I_SENDMODE", 0)
	return dest
end

-- Get all pfcbs
---@return table
function Get_pfcbs()
	local pfcbs = {}
	local sum_track, ok = Get_pfcb_sum_track()
	if ~ok then
		return pfcbs
	end
	for _, track in ipairs(Get_sends_to_dest(sum_track)) do
		table.insert(pfcbs, track)
	end
	return pfcbs
end

return Console
