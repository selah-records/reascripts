colors = {
	black = { 84, 84, 84 },
	blue = { 28, 101, 199 },
	lavender = { 144, 114, 156 },
	grey = { 168, 168, 168 },
	teal = { 19, 189, 153 },
	dark_teal = { 51, 152, 135 },
	brown = { 184, 143, 63 },
	rose = { 187, 156, 148 },
	dark_red = { 134, 94, 82 },
	brick = { 130, 59, 42 },
}

-- This type is provided by reaper, which we do not have LSP hooks for
---@alias Track any
---
function select_all_tracks()
	for i = 0, reaper.GetNumTracks() - 1 do
		reaper.SetTrackSelected(reaper.GetTrack(0, i), true)
	end
end

function deselect_all_tracks()
	for i = 0, reaper.GetNumTracks() - 1 do
		reaper.SetTrackSelected(reaper.GetTrack(0, i), false)
	end
end

---@param name string
---@return Track, integer
function get_track_by_name(name)
	-- TODO: what if we have multiple tracks with the same name?
	for i = 0, reaper.GetNumTracks() - 1 do
		track = reaper.GetTrack(0, i)
		ok, this_name = reaper.GetTrackName(track)
		if ok == false then
			return nil, -1
		end
		if name == this_name then
			return track, i
		end
	end
	return nil, -1
end

---@param name string
---@param index integer
---@param color integer
---@return Track, integer
function create_vca_track(name, index, color)
	reaper.InsertTrackAtIndex(index, false)
	track = reaper.GetTrack(0, index)
	reaper.SetTrackColor(track, color)
	reaper.GetSetMediaTrackInfo_String(track, "P_NAME", name, true)
	reaper.GetSetTrackGroupMembership(track, "VOLUME_LEAD", 1, 1)
	return track, index
end

---@param name string
---@param parent Track
---@param index integer
---@param color integer
---@return Track, integer
function create_folder(name, parent, color, index)
	reaper.InsertTrackAtIndex(index, false)
	local track = reaper.GetTrack(0, index)
	reaper.GetSetMediaTrackInfo_String(track, "P_NAME", name, true)

	reaper.SetTrackColor(track, color)
	reaper.SetMediaTrackInfo_Value(track, "I_FOLDERDEPTH", 0)
	reaper.SetMediaTrackInfo_Value(track, "I_FOLDERCOMPACT", 1)
	return track, index
end

function add_to_folder(index, children)
	for _, child_track in ipairs(children) do
		reaper.SetTrackSelected(child_track, true)
	end
	reaper.ReorderSelectedTracks(index + 1, 1)
	deselect_all_tracks()
end

---@return table
function index_to_folder_depth()
	local map = {}
	-- local folder_depth = 0
	-- local last_depth = 0
	local depth = 0
	for i = 0, reaper.GetNumTracks() - 1 do
		local track = reaper.GetTrack(0, i)
		local name = reaper.GetTrackState(track)
		map[i] = depth
		local step = reaper.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
		depth = depth + step
	end
	return map
end
