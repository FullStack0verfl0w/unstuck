util.AddNetworkString("AddChatText")

hook.Remove("Move", "CheckStuck")

// Thanks to Silverlan
local info_nodes = {}
local _R = debug.getregistry()
local nodegraph = _R.Nodegraph.Read()
for _, node in pairs(nodegraph:GetNodes()) do
	if node.type == NODE_TYPE_GROUND then
		table.insert(info_nodes, node.pos)
	end
end

local stuck_time_hint = CreateConVar("sv_unstuck_stuck_time_hint", 0.3, FCVAR_ARCHIVE, "How much time (in seconds) the player must be stuck, before it will get a message.")
local max_stuck_time = CreateConVar("sv_unstuck_max_stuck_time", 2, FCVAR_ARCHIVE, "How much time (in seconds) the player must be stuck, before it will be teleported.")

local PLAYER = FindMetaTable("Player")
///////////////////////////////////////////////////////////////////////////////
// This method sends colored chat message and adds it into the chat
///////////////////////////////////////////////////////////////////////////////
function PLAYER:AddChatText(...)
	local args = {...}
	net.Start("AddChatText")
		net.WriteTable(args)
	net.Send(self)
end

///////////////////////////////////////////////////////////////////////////////
// Helper function for merging multiply tables
///////////////////////////////////////////////////////////////////////////////
function MergeTables(...)
	local args = {...}
	local result = {}

	for k, v in pairs(args) do
		if istable(v) then
			table.Merge(result, v)
		end
	end
	return result
end

///////////////////////////////////////////////////////////////////////////////
// Find the nearest player_start entity and teleport stucked
// player into it location
///////////////////////////////////////////////////////////////////////////////
function UnstuckPlayer(ply, force_unstuck)
	local node_distances = {}
	local starts_distances = {}
	local starts = MergeTables(ents.FindByClass("info_player_deathmatch"),
							 	ents.FindByClass("info_player_start"),
							 	ents.FindByClass("info_player_counterterrorist"),
							 	ents.FindByClass("info_player_terrorist")
							 )
	local neareast_point, pos

	// If the map has info_nodes we'll use it
	if #info_nodes != 0 then
		// Insert into the table entities and their distances
		for k, v in pairs(info_nodes) do
			table.insert(node_distances, {v, ply:GetPos():Distance(v)})
		end
		// Sort nodes by distance.
		// Lowest distance is first
		table.sort(node_distances, function(a, b) return a[2] < b[2] end)
		pos = node_distances[1][1]

	// Or nearest player_start spot
	else
		// Insert into the table entities and their distances
		for k, v in pairs(starts) do
			table.insert(starts_distances, {v, ply:GetPos():Distance(v:GetPos())})
		end
		// Sort nodes by distance.
		// Lowest distance is first
		table.sort(starts_distances, function(a, b) return a[2] < b[2] end)

		neareast_point = starts_distances[1][1]
		pos = neareast_point:GetPos()
	end
	// There's a bug where PLAYER:SetPos
	// will not work in a Move-like hooks.
	// So, I did this. :D
	hook.Add("Think", "Unstuck_"..ply:UniqueID(),function()
		// Teleport the player on the nearest
		// player_start, but on 10 units higher
		ply:SetPos(Vector(pos.x, pos.y, pos.z + 10))

		// We don't want player stuck on the
		// player_start spot, don't we?
		hook.Remove("Think", "Unstuck_"..ply:UniqueID())
		ply:AddChatText(Color(255, 255, 150), "There you go... now stay outta that spot!")
	end)
end

///////////////////////////////////////////////////////////////////////////////
// Decide if he's stuck or not. We shall put it into the GM:Move hook
///////////////////////////////////////////////////////////////////////////////
function DetectPlayerStuck(ply, cmd)
	if !IsValid(ply) then return end // Nuh-uh

	// If player is stuck it counts like he's flying
	if !ply:IsOnGround() then
		// If you're inside the world your z velocity is -4.5
		// Minus one if block. Plus two commentary lines. Fuck you logic
		// Anyway, if you're not moving in z for too long...
		if (cmd:GetVelocity().z == -4.5) then
			if !ply.is_stuck then
				ply.stuck_time = CurTime() + stuck_time_hint:GetFloat()
				ply.is_stuck = true
			end

			// After we're pretty sure, put up a helpful message
			if (ply.stuck_time <= CurTime()
				|| ply.stuck_time + stuck_time_hint:GetFloat() <= CurTime()) then
					if !ply.is_printed then
						ply:AddChatText(Color(255, 255, 150), "You look like you're stuck.")
						ply.is_printed = true
					end
				end

			// Now that he's really stuck. Reset variables
			// and teleport him
			if (ply.stuck_time + max_stuck_time:GetFloat() < CurTime()) then
				ply.stuck_time = 0

				UnstuckPlayer(ply)

				ply.is_stuck = false
			end
		else
			ply.stuck_time = 0
			ply.is_stuck = false
			ply.is_printed = nil
		end
	end
end
hook.Add("Move", "CheckStuck", DetectPlayerStuck)