local path = ({ reaper.get_action_context() })[2]:match("^.+[\\//]")
-- dofile(path .. "lib.lua")
require(path .. "console")

-- Help the LSP
local reaper = reaper

local console_channel = "Console7Channel"
local console_buss = "Console7Channel"

reaper.Undo_BeginBlock()

-- Create a console sum buss if we do not already have one.
local sum_buss, ok = Get_pfcb_sum_track()
if ok == false then
	reaper.ShowConsoleMsg("Creating sum buss\n")
	local idx = reaper.CountTracks(0)
	reaper.InsertTrackInProject(0, idx, 0)
	sum_buss = reaper.GetTrack(0, idx)
	reaper.GetSetMediaTrackInfo_String(sum_buss, "P_NAME", "PFCB_SUM", true)
	reaper.SetMediaTrackInfo_Value(sum_buss, "B_SHOWINTCP", 0)
	reaper.SetMediaTrackInfo_Value(sum_buss, "B_SHOWINMIXER", 0)
	-- TODO: add linked gain control
	reaper.TrackFX_AddByName(sum_buss, "AU:" .. console_buss, 0, 1)
end

-- Enumerate all tracks routed to master. These all need to be rerouted to a console sum buss.
local tracks = Get_tracks_routed_to_master()

-- For each track, create a pfcb (post-fader console send), route the track into that bus, and *remove* the master send for the track.
for _, track in ipairs(tracks) do
	local _, name = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
	if name == "PFCB_SUM" then
	-- pass
	else
		reaper.SetMediaTrackInfo_Value(track, "B_MAINSEND", 0)
		local send = Create_pfcb(track, sum_buss)
		-- TODO: add linked gain control
		reaper.TrackFX_AddByName(send, "AU:" .. console_channel, 0, 1)
	end
end

reaper.Undo_EndBlock("set up console", 0)
