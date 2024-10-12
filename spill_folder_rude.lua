local path = ({ reaper.get_action_context() })[2]:match("^.+[\\//]")
dofile(path .. "lib.lua")

local reaper = reaper

reaper.Undo_BeginBlock()
local folder_depth = index_to_folder_depth()

local top_level_tracks = 0
local current_folder = nil
for i = 0, reaper.GetNumTracks() - 1 do
	local track = reaper.GetTrack(0, i)
	local _, state = reaper.GetTrackState(track)
	-- Check whether track is visible
	if reaper.GetMediaTrackInfo_Value(track, "B_SHOWINMIXER") == 1 then
		if folder_depth[i] == 0 then
			current_folder = track
			top_level_tracks = top_level_tracks + 1
		end
	end
end

if top_level_tracks == 1 then
	for i = 0, reaper.GetNumTracks() - 1 do
		local track = reaper.GetTrack(0, i)
		if folder_depth[i] == 0 then
			reaper.SetMediaTrackInfo_Value(track, "B_SHOWINMIXER", 1)
		else
			reaper.SetMediaTrackInfo_Value(track, "B_SHOWINMIXER", 0)
		end
	end
	select_all_tracks()
	-- Force change into effect
	reaper.ReorderSelectedTracks(0, 0)
	deselect_all_tracks()
	reaper.SetTrackSelected(current_folder, true)
	return
end

local i = 0
while i < reaper.GetNumTracks() - 1 do
	local track = reaper.GetTrack(0, i)
	local _, state = reaper.GetTrackState(track)
	-- Check whether track is selected
	if (state & 2) == 2 then
		if folder_depth[i] == 0 then
			while i < reaper.GetNumTracks() - 1 do
				i = i + 1
				if folder_depth[i] == 0 then
					break
				end
				local child_track = reaper.GetTrack(0, i)
				if reaper.GetMediaTrackInfo_Value(child_track, "B_SHOWINMIXER") == 0 then
					reaper.SetMediaTrackInfo_Value(child_track, "B_SHOWINMIXER", 1)
				else
					reaper.SetMediaTrackInfo_Value(child_track, "B_SHOWINMIXER", 0)
				end
			end
		end
	else
		reaper.SetMediaTrackInfo_Value(reaper.GetTrack(0, i), "B_SHOWINMIXER", 0)
		i = i + 1
	end
end
local save_selected_tracks = {}
for i = 0, reaper.GetNumTracks() - 1 do
	local track = reaper.GetTrack(0, i)
	local _, state = reaper.GetTrackState(track)
	if (state & 2) == 2 then
		table.insert(save_selected_tracks, i)
	end
	reaper.SetTrackSelected(track, true)
end
-- Force change into effect
reaper.ReorderSelectedTracks(0, 0)
deselect_all_tracks()
-- Reselect any tracks that were selected before
for _, i in ipairs(save_selected_tracks) do
	reaper.SetTrackSelected(reaper.GetTrack(0, i), true)
end
reaper.Undo_EndBlock("spill folder", 0)
