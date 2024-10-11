Schema = {
	{
		patterns = { "snare", "kick", "overhead", "oh", "tom", "ride" },
		color = 0x256,
		-- icon = "icon.png",
		vca = "",
		bus = "Drum Bus",
	},
	{
		patterns = { "vox", "vocal" },
		color = 0x450,
		-- icon = "icon.png",
		vca = "VOX_vca",
		bus = "",
	},
	{
		patterns = { "bgv", "background", "backing" },
		color = 0x5000,
		-- icon = "icon.png",
		vca = "VOX_vca",
		bus = "BGV",
	},
	{
		patterns = { "bass", "sub", "808", "909" },
		color = 0x100,
		-- icon = "icon.png",
		vca = "BASS_vca",
		bus = "",
	},
	{
		patterns = { "guitar", "acoustic", "electric" },
		color = 0x600,
		-- icon = "icon.png",
		vca = "GUITAR_vca",
		bus = "",
	},
	{
		patterns = { "synth", "moog", "pad", "arp", "juno", "saw" },
		color = 0x600,
		-- icon = "icon.png",
		vca = "SYNTH_vca",
		bus = "",
	},
	{
		patterns = { "fx", "effect", "riser", "drop" },
		color = 0x600,
		-- icon = "icon.png",
		vca = "FX_vca",
		bus = "FX",
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
local function create_vca_track(name) end

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
	reaper.SetMediaTrackInfo_Value(track, "I_FOLDERCOMPACT", 0)
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

local colors = { [-2] = 40000, [-1] = 0x20000, [0] = 0x256, [1] = 0x5000, [2] = 0x100, [3] = 0x600000 }
local folder_depth = index_to_folder_depth()
local to_add_to_folders = {}
for _, group in pairs(Schema) do
	to_add_to_folders[group] = {}
end

for i = 0, reaper.GetNumTracks() - 1 do
	track = reaper.GetTrack(0, i)
	name, _ = reaper.GetTrackState(track)
	reaper.ShowConsoleMsg(name)
	reaper.ShowConsoleMsg(":")
	reaper.ShowConsoleMsg(folder_depth[i])
	reaper.ShowConsoleMsg("\n")
end

for i = 0, reaper.GetNumTracks() - 1 do
	-- Ignore tracks already inside a folder
	if folder_depth[i] == 0 then
		track = reaper.GetTrack(0, i)
		_, track_name = reaper.GetTrackName(track)
		for _, group in ipairs(Schema) do
			for _, pattern in ipairs(group.patterns) do
				if string.match(string.upper(track_name), string.upper(pattern)) then
					reaper.SetTrackColor(track, group.color)
					if group.bus ~= "" then
						table.insert(to_add_to_folders[group], track)
					end
				end
			end
		end
	end
end
for group, tracks in pairs(to_add_to_folders) do
	if #tracks > 0 then
		local folder_track, index = get_track_by_name(bus)
		if index == -1 then
			_, index = create_folder(group.bus, nil, group.color, 0)
		else
			if folder_depth[index] == 0 then
				_, index = create_folder(group.bus, nil, group.color, 0)
			end
		end
		add_to_folder(index, tracks)
	end
end
