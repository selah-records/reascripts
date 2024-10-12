local colors = {
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

Schema = {
	{
		patterns = { "vox", "vocal" },
		components = {
			lead = {
				patterns = { "vox", "lead" },
			},
			double = {
				patterns = { "double", "wide" },
			},
		},
		order = { "lead", "double" },
		color = colors.blue,
		-- icon = "icon.png",
		vca = "",
		folder = "Vox",
	},
	{
		components = {
			bgv = {
				patterns = { "bgv", "background", "backing", "harm" },
			},
		},
		order = { "bgv" },
		color = colors.lavender,
		-- icon = "icon.png",
		vca = "",
		folder = "BGVs",
	},
	{
		components = {
			kick = {
				patterns = { "kick" },
			},
			snare = {
				patterns = { "snare" },
			},
			overhead = {
				patterns = { "overhead", "oh" },
			},
			room = {
				patterns = { "drum room", "drum_room" },
			},
			hats = {
				patterns = { "hats", "hihat", "hi hat", "hi-hat" },
			},
			tom = {
				patterns = { "tom", "toms" },
			},
		},
		order = { "kick", "snare", "overhead", "room", "hats", "tom" },
		color = colors.brown,
		-- icon = "icon.png",
		vca = "",
		folder = "Drums",
	},
	{
		components = {
			bass_guitar = {
				patterns = { "bass" },
			},
			synth_bass = {
				patterns = { "sub", "808", "909", "sh101", "sh-101" },
			},
		},
		order = { "bass_guitar", "synth_bass" },
		color = colors.dark_red,
		-- icon = "icon.png",
		vca = "",
		folder = "Bass",
	},
	{
		components = {
			acoustic = {
				patterns = { "acoustic", "classical", "nylon", "steel", "picking", "martin", "taylor" },
			},
			electric = {
				patterns = { "guitar", "electric", "chug", "heavy", "strat", "tele", "les paul", "sg" },
			},
		},
		order = { "acoustic", "electric" },
		color = colors.teal,
		-- icon = "icon.png",
		vca = "",
		folder = "Guitars",
	},
	{
		components = {
			lead = {
				patterns = { "moog", "juno", "synth lead", "anthem", "big room", "big_room", "synth solo", "arp" },
			},
			chords = {
				patterns = { "chicago", "chords", "saws", "synth" },
			},
			pads = {
				patterns = { "pad", "atmospheric" },
			},
		},
		order = { "lead", "chords", "pads" },
		color = colors.rose,
		-- icon = "icon.png",
		vca = "",
		folder = "Synths",
	},
	{
		components = {
			fx = {
				patterns = { "fx", "effect", "riser", "drop" },
			},
		},
		order = { "fx" },
		color = colors.grey,
		-- icon = "icon.png",
		vca = "",
		folder = "FX",
	},
}

-- This type is provided by reaper, which we do not have LSP hooks for
---@alias Track any

local function deselect_all_tracks()
	for i = 0, reaper.GetNumTracks() - 1 do
		reaper.SetTrackSelected(reaper.GetTrack(0, i), false)
	end
end

---@param name string
---@return Track, integer
local function get_track_by_name(name)
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
local function create_vca_track(name, index, color)
	reaper.InsertTrackAtIndex(index, false)
	track = reaper.GetTrack(0, index)
	reaper.SetTrackColor(track, color)
	reaper.GetSetMediaTrackInfo_String(track, "P_NAME", name, true)
	reaper.GetSetTrackGroupMembership(track, "VOLUME_LEAD", 1, 1)
	return track, index
end

---@param name string
---@param parent Track
---@param children Track[]
---@param index integer
---@param color integer
---@return Track, integer
local function create_folder(name, parent, color, index)
	reaper.InsertTrackAtIndex(index, false)
	local track = reaper.GetTrack(0, index)
	reaper.GetSetMediaTrackInfo_String(track, "P_NAME", name, true)

	reaper.SetTrackColor(track, color)
	reaper.SetMediaTrackInfo_Value(track, "I_FOLDERDEPTH", 0)
	reaper.SetMediaTrackInfo_Value(track, "I_FOLDERCOMPACT", 1)
	return track, index
end

local function add_to_folder(index, children)
	for _, child_track in ipairs(children) do
		reaper.SetTrackSelected(child_track, true)
	end
	reaper.ReorderSelectedTracks(index + 1, 1)
	deselect_all_tracks()
end

---@return table
local function index_to_folder_depth()
	local map = {}
	local folder_depth = 0
	local last_depth = 0
	for i = 0, reaper.GetNumTracks() - 1 do
		local track = reaper.GetTrack(0, i)
		depth = reaper.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
		if depth == 1 then
			folder_depth = folder_depth + 1
		end
		if depth == 0 and last_depth == 1 then
			folder_depth = folder_depth + 1
		end
		if last_depth == -1 then
			folder_depth = folder_depth - 2
		end
		if last_depth == -2 then
			folder_depth = folder_depth - 3
		end
		map[i] = folder_depth
		last_depth = depth
	end
	return map
end

---@param  str string
---@return string
local function upper_first(str)
	return (str:gsub("^%l", string.upper))
end

---@param track_name string
---@return string
local function format_track_name(name)
	local sep = " "
	local parts = {}
	for part in string.gmatch(name, "([^" .. sep .. "]+)") do
		table.insert(parts, part)
	end
	local formatted_name = ""
	for _, part in ipairs(parts) do
		formatted_name = formatted_name .. upper_first(part)
	end
	return formatted_name
end

------------------------
-- Script begins here
------------------------
deselect_all_tracks()

local folder_depth = index_to_folder_depth()
local to_add_to_folders = {}
for _, group in ipairs(Schema) do
	to_add_to_folders[group] = {}
end
local to_add_to_vcas = {}
for _, group in ipairs(Schema) do
	to_add_to_vcas[group] = {}
end

for i = 0, reaper.GetNumTracks() - 1 do
	track = reaper.GetTrack(0, i)
	name, _ = reaper.GetTrackState(track)
	-- reaper.ShowConsoleMsg(name)
	-- reaper.ShowConsoleMsg(":")
	-- reaper.ShowConsoleMsg(folder_depth[i])
	-- reaper.ShowConsoleMsg("\n")
end

reaper.Undo_BeginBlock()
for i = 0, reaper.GetNumTracks() - 1 do
	-- Ignore tracks already inside a folder
	if folder_depth[i] == 0 then
		track = reaper.GetTrack(0, i)
		_, track_name = reaper.GetTrackName(track)
		for _, group in ipairs(Schema) do
			for _, component_name in ipairs(group.order) do
				for _, pattern in ipairs(group.components[component_name].patterns) do
					if string.match(string.upper(track_name), string.upper(pattern)) then
						reaper.SetTrackColor(track, reaper.ColorToNative(table.unpack(group.color)))
						reaper.GetSetMediaTrackInfo_String(track, "P_NAME", format_track_name(track_name), true)
						reaper.SetMediaTrackInfo_Value(track, "B_SHOWINMIXER", 0)
						if group.folder ~= "" then
							table.insert(to_add_to_folders[group], track)
						end
						if group.vca ~= "" then
							table.insert(to_add_to_vcas[group], track)
						end
					end
				end
			end
		end
	end
end
-- for _, group in ipairs(Schema) do
for i = #Schema - 1, 1, -1 do
	local group = Schema[i]
	local tracks = to_add_to_folders[group]
	if #tracks > 0 then
		local folder_track, index = get_track_by_name(group.folder)
		if index == -1 then
			_, index = create_folder(group.folder, nil, reaper.ColorToNative(table.unpack(group.color)), 0)
		else
			if folder_depth[index] ~= 1 then
				_, index = create_folder(group.folder, nil, reaper.ColorToNative(table.unpack(group.color)), 0)
			end
		end
		for _, track in ipairs(tracks) do
			reaper.SetTrackSelected(track, true)
		end
		reaper.ReorderSelectedTracks(index + 1, 1)
		deselect_all_tracks()
	end
end
for _, group in ipairs(Schema) do
	-- for i = #Schema - 1, 1, -1 do
	-- local group = Schema[i]
	local tracks = to_add_to_vcas[group]
	for _, tracks in ipairs(to_add_to_vcas[group]) do
		if #tracks > 0 then
			local vca_track, index = get_track_by_name(group.vca)
			if index == -1 then
				vca_track = create_vca_track(group.vca, 0, reaper.ColorToNative(table.unpack(group.color)))
			end
			-- TODO: need to keep track of groups in use
			for _, track in ipairs(tracks) do
				reaper.GetSetTrackGroupMembership(track, "VOLUME_FOLLOW", 1, 1)
			end
		end
	end
end
reaper.Undo_EndBlock("clean up tracks", 0)
