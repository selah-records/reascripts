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
		patterns = { "snare", "kick", "overhead", "oh", "tom", "ride" },
		color = colors.brown,
		-- icon = "icon.png",
		vca = "",
		folder = "Drums",
	},
	{
		patterns = { "vox", "vocal" },
		color = colors.blue,
		-- icon = "icon.png",
		vca = "",
		folder = "Vox",
	},
	{
		patterns = { "bgv", "background", "backing" },
		color = colors.lavender,
		-- icon = "icon.png",
		vca = "",
		folder = "BGVs",
	},
	{
		patterns = { "bass", "sub", "808", "909" },
		color = colors.dark_red,
		-- icon = "icon.png",
		vca = "",
		folder = "Bass",
	},
	{
		patterns = { "guitar", "acoustic", "electric" },
		color = colors.teal,
		-- icon = "icon.png",
		vca = "",
		folder = "Guitars",
	},
	{
		patterns = { "synth", "moog", "pad", "arp", "juno", "saw" },
		color = colors.rose,
		-- icon = "icon.png",
		vca = "",
		folder = "Synths",
	},
	{
		patterns = { "fx", "effect", "riser", "drop" },
		color = colors.grey,
		-- icon = "icon.png",
		vca = "",
		folder = "FX",
	},
}

-- This type is provided by reaper, which we do not have LSP hooks for
---@alias Track any

local vca_color = 0x900
local default_bus_color = 0x800

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

deselect_all_tracks()

local folder_depth = index_to_folder_depth()
local to_add_to_folders = {}
for _, group in pairs(Schema) do
	to_add_to_folders[group] = {}
end
local to_add_to_vcas = {}
for _, group in pairs(Schema) do
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
			for _, pattern in ipairs(group.patterns) do
				if string.match(string.upper(track_name), string.upper(pattern)) then
					reaper.SetTrackColor(track, reaper.ColorToNative(table.unpack(group.color)))
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
for group, tracks in pairs(to_add_to_folders) do
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
for group, tracks in pairs(to_add_to_vcas) do
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
reaper.Undo_EndBlock("clean up tracks", 0)
