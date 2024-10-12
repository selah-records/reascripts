local path = ({ reaper.get_action_context() })[2]:match("^.+[\\//]")
dofile(path .. "lib.lua")

local reaper = reaper

reaper.Undo_BeginBlock()
local folder_depth = index_to_folder_depth()
for i = 0, reaper.GetNumTracks() - 1 do
	local track = reaper.GetTrack(0, i)
	local _, state = reaper.GetTrackState(track)
	-- Check whether track is selected
	if (state & 2) == 2 then
		if folder_depth[i] == 0 then
			for j = i + 1, reaper.GetNumTracks() - 1 do
				local child_track = reaper.GetTrack(0, j)
				if reaper.GetMediaTrackInfo_Value(child_track, "B_SHOWINMIXER") == 0 then
					reaper.SetMediaTrackInfo_Value(child_track, "B_SHOWINMIXER", 1)
				else
					reaper.SetMediaTrackInfo_Value(child_track, "B_SHOWINMIXER", 0)
				end
				if folder_depth[j + 1] == 0 then
					break
				end
			end
		end
		break
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
