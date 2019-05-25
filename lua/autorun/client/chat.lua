net.Receive("AddChatText",function(len)
	local args = util.Decompress(net.ReadData())

	chat.AddText(unpack(args))
end)