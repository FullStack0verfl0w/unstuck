util.AddNetworkString("AddChatText")

hook.Remove("Move", "CheckStuck")

local STUCK_TIME_HINT = 0.3
local MAX_STUCK_TIME = 2

local PLAYER = FindMetaTable("PLAYER")
///////////////////////////////////////////////////////////////////////////////
// This method sends colored chat message and adds it into the chat
///////////////////////////////////////////////////////////////////////////////
function PLAYER:AddChatText(...)
	local args = {...}
	net.Start("AddChatText")
		// Compress us much as possible
		net.WriteData(util.Compress(util.TableToJSON(args)))
	net.Send(self)
end

///////////////////////////////////////////////////////////////////////////////
// Helper function for merging multiply tables
///////////////////////////////////////////////////////////////////////////////
function MergeTables(...)
	local args = {...}
	local result = {}

	for k, v in pairs(args) do
		table.Merge(v, result)
	end
	return result
end

///////////////////////////////////////////////////////////////////////////////
// Find the nearest player_start entity and teleport stucked
// player into it location
///////////////////////////////////////////////////////////////////////////////
function UnstuckPlayer(ply)
	local node_distances = {}
	local nodes = MergeTables(ents.FindByClass("info_player_deathmatch"),
							 	ents.FindByClass("info_player_start"),
							 	ents.FindByClass("info_player_counterterrorist"),
							 	ents.FindByClass("info_player_terrorist")
							 )

	// Insert into the table entity itself and it distance
	for k, v in pairs(nodes) do
		table.insert(node_distances, {v, ply:GetPos():Distance(v:GetPos())})
	end
	// Sort nodes by distance.
	// Lowest distance is first
	table.sort(node_distances, function(a, b) return a[2] < b[2] end)

	local pos = node_distances[1][1]:GetPos()

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
	// If player is stuck it counts like he's flying
	if !ply:IsOnGround() then

		// If you're inside the world your z velocity is -4.5
		// Minus one if block. Plus two commentary lines. Fuck you logic
		// Anyway, if you're not moving in z for too long...
		if (cmd:GetVelocity().z == -4.5) then
			if !ply.is_stuck then
				ply.stuck_time = CurTime() + STUCK_TIME_HINT
				ply.is_stuck = true
			end

			// After we're pretty sure, put up a helpful message
			if (ply.stuck_time <= CurTime()
				|| ply.stuck_time + STUCK_TIME_HINT <= CurTime()) then
					if !ply.is_printed then
						ply:AddChatText(Color(255, 255, 150), "You look like you're stuck.")
						ply.is_printed = true
					end
				end

			// Now that he's really stuck. Reset variables
			// and teleport him
			if (ply.stuck_time + MAX_STUCK_TIME < CurTime()) then
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