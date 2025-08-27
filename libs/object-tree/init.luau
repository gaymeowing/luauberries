--!native

--[[
	object tree
	library for generating tree structures for objects on a shelf
	to prevent floating objects from ever happening
]]

local random = require("@libs/random")

export type FaceTaperTowardsSide = "Front" | "Back" | "Left" | "Right"
-- TaperType names are reffering to roof types, ie bloxburg roof types
export type TaperType = "Pyramid" | "Slope" | "Flat" | "Hip"

export type Tree = {
	current_stock: number,
	max_stock: number,
	position: vector,
	nodes: { Node },
	tree_id: number,
}

type BaseNode<HOS, S, N> = {
	--[[
		Indicates if this node can be grabbed, as in there are no taken nodes above this node and this node itself is also taken.
	]]
	takeable: boolean,
	--[[
		Indicates if the node has only a single supporter, this is purely internal
		and only used by `object_tree.closest_empty_node`,
		as an optimization for trees that have a taper type of "Flat" or "Slope".
	]]
	has_one_supporter: HOS,
	--[[
		Array of nodes that are supported by this node, if `nil` this node is at the bottom of the tree.
	]]
	supported: { N }?, -- not using the node type here because then the recursive type error comes to haunt me
	--[[
		The position this node is at within the DataModel
	]]
	position: vector,
	--[[
		Indicates if this node is taken,
	]]
	taken: boolean,
	--[[
		The CFrame this node is at within the DataModel
	]]
	cframe: CFrame,
	--[[
		Either an array of nodes that are supported by this node, or if `has_one_supporter` is true this points to a node directly below this node,
		and if `nil` this node is at the top of the tree.
	]]
	supporter: S?,
}

export type Node = BaseNode<true, Node, Node> | BaseNode<false, { Node }, Node>

export type FillInfo = {
	-- This option will only work if TaperType == "Slope" or "Hip", where it will make the slope face that side
	face_taper_towards_side: FaceTaperTowardsSide?,
	-- if set it can only randomly rotate the objects within the range given
	object_random_rotation_min_max: NumberRange?,
	-- If given BoxFill will only taper the the layers after the Index (TotalLayers - TotalTopLayersToTaper)
	-- NOTE: if TotalLayers - TotalTopLayersToTaper is not greater than 1 then
	-- BoxFill will error as indexs cant be less than 1
	-- and you cant taper the first layer
	total_top_layers_to_taper: number?,
	-- if enabled it will randomly rotate the objects
	randomly_rotate_objects: boolean?,
	object_rotation_offset: vector?,
	max_objects_xyz: vector?,
	taper_type: TaperType?,
	should_stack: boolean?,
	object_size: vector,
	box_cframe: CFrame?,
	padding: Vector2?,
	box_size: vector,
}

type NodeConnector = (
	node_cframe: CFrame,
	object_size: vector,
	face_taper_towards_side: FaceTaperTowardsSide,
	layer_below: { Node }
) -> { Node }

type LayerEditor = (
	object_size: vector,
	box_size: vector,
	index: number,
	face_taper_towards_side: FaceTaperTowardsSide,
	bottom_box_cframe: CFrame,
	box_size_halved: vector
) -> (vector, CFrame)

type TaperTransformer = {
	node_connector: NodeConnector,
	layer_editor: LayerEditor,
}

local DEFUALT_RANDOM_ROTATE_MIN_MAX = NumberRange.new(0, 10)
local STARTING_INDEX = -0.001
local TREE_ID = 0

local function GET_NODES_CLOSEST_TO_POSITION(layer_below: { Node }, position: vector, node_amount: number): { Node }
	local nodes = table.create(node_amount)

	for index = 1, node_amount do
		local closest_magnitude = math.huge
		local closest_node: Node

		for _, node in layer_below do
			if table.find(nodes, node) then
				continue
			end
			local magnitude = vector.magnitude(position - node.position)

			if magnitude < closest_magnitude then
				closest_magnitude = magnitude
				closest_node = node
			end
		end

		nodes[index] = closest_node
	end
	return nodes
end

local function GET_POSITION_OF_NODE_BELOW(node_cframe: CFrame, object_size: Vector3): Vector3
	return (node_cframe * CFrame.new(0, -object_size.y, 0)).Position
end

local function FLAT_NODE_CONNECTOR(
	node_cframe: CFrame, object_size: vector,
	face_taper_towards_side: FaceTaperTowardsSide,
	layer_below: { Node }
): { Node }
	local below_position = GET_POSITION_OF_NODE_BELOW(node_cframe, object_size)
	local nearest_dist = math.huge
	local nearest_node: Node

	for _, node in layer_below do
		local dist = vector.magnitude(below_position - node.position)

		if dist < nearest_dist then
			nearest_dist = dist
			nearest_node = node
		end
	end
	return { nearest_node }
end

local function GET_NODE_CFRAME(
	layer_cframe: CFrame, x: number, z: number, diff_x: number,
	diff_z: number, object_rotation_offset: CFrame
): CFrame
	return (layer_cframe * CFrame.new(x - diff_x, 0, z - diff_z)) * object_rotation_offset
end

--[[
	returns (layer_cframe, steps, diff_x, diff_z )
]]
local function GET_LAYER_INFO(
	object_size: vector, half_object_size: vector, half_object_height: number,
	layer_size: vector, bottom_box_cframe: CFrame, prev_index: number
): (CFrame, vector, number, number)
	local size_diff = (layer_size / 2) - half_object_size

	return
		bottom_box_cframe * CFrame.new(0, (object_size.y * prev_index) + half_object_height, 0),
		layer_size - object_size,
		size_diff.x,
		size_diff.z
end

local function get_object_rotation_offset(info: FillInfo): CFrame
	local object_rotation_offset = info.object_rotation_offset

	return if object_rotation_offset then
			CFrame.Angles(
				math.rad(object_rotation_offset.x),
				math.rad(object_rotation_offset.y),
				math.rad(object_rotation_offset.z)
			)
		else
			CFrame.identity
end

local function get_padding(info: FillInfo): vector
	local padding = info.padding

	if padding then
		if typeof(padding) == "Vector2" then
			return vector.create(padding.X, padding.Y, 0)
		end

		return padding
	end

	return vector.zero
end

local FLAT_TAPER_TRANSFORMER = table.freeze({
	layer_editor = function(object_size, box_size, index, face_taper_towards_side, cframe)
		return box_size, cframe
	end,
	node_connector = FLAT_NODE_CONNECTOR,
}) :: TaperTransformer

local TAPER_TRANSFORMERS = table.freeze {
	Pyramid = table.freeze({
		node_connector = function(node_cframe, object_size, face_taper_towards_side, layer_below)
			return GET_NODES_CLOSEST_TO_POSITION(
				layer_below,
				GET_POSITION_OF_NODE_BELOW(node_cframe, object_size),
				4
			)
		end,
		layer_editor = function(object_size, box_size, index, face_taper_towards_side, cframe)
			return box_size - vector.create(object_size.x * index, 0, object_size.z * index), cframe
		end,
	} :: TaperTransformer),

	Slope = table.freeze({
		layer_editor = function(
			object_size, box_size, index, face_taper_towards_side, cframe, size_halved
		)
			if face_taper_towards_side == "Front" then
				local layer_cframe = cframe * CFrame.new(0, 0, -size_halved.z)

				return box_size - vector.create(0, 0, object_size.z * index),
					layer_cframe * CFrame.new(0, 0, box_size.z / 2)
			elseif face_taper_towards_side == "Right" then
				local layer_cframe = box_cframe * CFrame.new(size_halved.x, 0, 0)

				return box_size - vector.create(object_size.x * index, 0, 0),
					layer_cframe * CFrame.new(-box_size.x / 2, 0, 0)
			elseif face_taper_towards_side == "Left" then
				local layer_cframe = box_cframe * CFrame.new(-size_halved.x, 0, 0)

				return box_size - vector.create(object_size.x * index, 0, 0),
					layer_cframe * CFrame.new(box_size.x / 2, 0, 0)
			else -- back
				local layer_cframe = box_cframe * CFrame.new(0, 0, size_halved.z)

				return box_size - vector.create(0, 0, object_size.z * index),
					layer_cframe * CFrame.new(0, 0, -box_size.z / 2)
			end
		end,
		--[[
			slope is basically the same as flat, as in theres always going to be a node directly below any node
			so it just uses the same node connector as flat
		]]
		node_connector = FLAT_NODE_CONNECTOR,
	} :: TaperTransformer),

	Hip = table.freeze({
		node_connector = function(node_cframe, object_size, face_taper_towards_side, layer_below)
			local neg_object_size = -object_size
			local aprox_below_position = if face_taper_towards_side == "Right" or face_taper_towards_side == "Left" then
					(node_cframe * CFrame.new(0, neg_object_size.y, neg_object_size.z)).Position
				else
					(node_cframe * CFrame.new(neg_object_size.x, neg_object_size.y, 0)).Position

			return GET_NODES_CLOSEST_TO_POSITION(layer_below, aprox_below_position, 2)
		end,
		layer_editor = function(object_size, box_size, index, face_taper_towards_side, cframe)
			local sub_vector = if face_taper_towards_side == "Front" or face_taper_towards_side == "Back" then
					vector.create(object_size.x * index, 0, 0)
				else
					-- right and left
					vector.create(0, 0, object_size.z * index)

			return box_size - sub_vector, cframe
		end,
	} :: TaperTransformer),

	Flat = FLAT_TAPER_TRANSFORMER,
}

local function get_taper_transformer(info: FillInfo): TaperTransformer
	local taper_type = info.taper_type

	if taper_type then
		local transformer = TAPER_TRANSFORMERS[taper_type]

		if transformer then
			return transformer
		else
			error(`[OBJECT TREE]: no taper transformer exists for taper type '{taper_type}'`)
		end
	else
		return FLAT_TAPER_TRANSFORMER
	end
end

local object_tree = {}

function object_tree.generate(info: FillInfo): Tree
	local face_taper_towards_side = info.face_taper_towards_side or "Back"
	local total_top_layers_to_taper = info.total_top_layers_to_taper
	local object_rotation_offset = get_object_rotation_offset(info)
	local box_cframe = info.box_cframe or CFrame.identity
	local max_objects = info.max_objects_xyz
	local padding = get_padding(info)

	local object_size = info.object_size + padding
	local starting_box_size = info.box_size
	local box_size = starting_box_size - padding

	if object_size.x > box_size.x or object_size.y > box_size.y or object_size.z > box_size.z then
		error("[OBJECT TREE]: 'object_size' cannot be greater than 'box_size'")
	end

	-- calaculating the most amount of objects that can fit within the given box size
	local objects_per_side = box_size // object_size

	if objects_per_side.x < 1 or objects_per_side.y < 1 or objects_per_side.z < 1 then
		error("[OBJECT TREE]: cannot fit a single object into the given 'box_size'")
	end

	if max_objects then
		objects_per_side = vector.clamp(objects_per_side, vector.one, max_objects)
	end

	box_size = objects_per_side * object_size

	local bottom_box_cframe = box_cframe * CFrame.new(0, -starting_box_size.y / 2, 0)
	local total_layers = if info.should_stack then objects_per_side.y else 1
	local half_object_size = object_size / 2
	local half_object_height = half_object_size.y
	local taper_starting_index = 2

	if total_top_layers_to_taper then
		taper_starting_index = total_layers - total_top_layers_to_taper

		if 1 >= taper_starting_index then
			error(`[OBJECT TREE]: 'total_layers' - 'total_top_layers_to_taper' is less than 1, cannot start taper below 2`)
		end
	end

	local transformer = get_taper_transformer(info)
	local layer_editor = transformer.layer_editor
	local node_connector = FLAT_NODE_CONNECTOR
	local box_size_halved = box_size / 2
	local object_size_x = object_size.x
	local object_size_z = object_size.z
	local nodes = {} :: { Node }
	local prev_nodes: { Node }
	local node_count = 0

	do
		local layer_cframe, steps, diff_x, diff_z = GET_LAYER_INFO(
			object_size, half_object_size, half_object_height,
			box_size, bottom_box_cframe, 0
		)
		local layer_nodes = {}

		--[[
			using -0.001 as 1 has an offset that doesnt correctly
			center cframes properly, and -0.001 because the
			minimum amount you can move a part/model is by 0.001
		]]
		for x = STARTING_INDEX, steps.x, object_size_x do
			for z = STARTING_INDEX, steps.z, object_size_z do
				local node_cframe = GET_NODE_CFRAME(layer_cframe, x, z, diff_x, diff_z, object_rotation_offset)
				table.insert(layer_nodes, {
					position = node_cframe.Position,
					takeable = false,
					cframe = node_cframe,
					taken = true,
				})
				node_count += 1
			end
		end

		prev_nodes = layer_nodes
	end

	table.move(prev_nodes, 1, node_count, 1, nodes)

	if total_layers ~= 1 then
		local layer_size = box_size
		local prev_index = 1

		for index = 2, total_layers do
			-- cannot do >= because otherwise itll taper for an extra layer
			local should_start_taper = index > taper_starting_index
			local layer_cframe, steps, diff_x, diff_z = GET_LAYER_INFO(
				object_size, half_object_size, half_object_height,
				layer_size, bottom_box_cframe, prev_index
			)
			local layer_nodes = {} :: { Node }
			local layer_node_count = 0

			if should_start_taper then
				layer_size, layer_cframe = layer_editor(
					object_size, layer_size, prev_index,
					face_taper_towards_side :: any, layer_cframe, box_size_halved
				)
				node_connector = transformer.node_connector
			end

			for x = STARTING_INDEX, steps.x, object_size_x do
				for z = STARTING_INDEX, steps.z, object_size_z do
					local node_cframe = GET_NODE_CFRAME(layer_cframe, x, z, diff_x, diff_z, object_rotation_offset)
					local supporter = node_connector(node_cframe, object_size, face_taper_towards_side :: any, prev_nodes)
					local has_one_supporter = not supporter[2]
					local node = {
						supporter = if has_one_supporter then supporter[1] else supporter,
						has_one_supporter = has_one_supporter,
						position = node_cframe.Position,
						takeable = false,
						cframe = node_cframe,
						taken = true,
					}

					for _, supporter_node in supporter do
						local supported = supporter_node.supported

						if supported then
							table.insert(supported, node)
						else
							supporter_node.supported = { node }
						end
					end

					table.insert(layer_nodes, node)
					layer_node_count += 1
				end
			end

			if layer_node_count ~= 0 then
				table.move(layer_nodes, 1, layer_node_count, node_count + 1, nodes)
				node_count += layer_node_count
				prev_nodes = layer_nodes
				prev_index = index
			else
				break
			end
		end
	end

	-- setting all the nodes at the top to be able to be grabbed
	for _, node in prev_nodes do
		node.takeable = true
	end

	if info.randomly_rotate_objects then
		local object_random_rotation_min_max = info.object_random_rotation_min_max
			or DEFUALT_RANDOM_ROTATE_MIN_MAX
		local min = object_random_rotation_min_max.Min
		local max = object_random_rotation_min_max.Max

		for _, node in nodes do
			node.cframe *= CFrame.Angles(
				math.rad(random.float(min, max)),
				math.rad(random.float(min, max)),
				math.rad(random.float(min, max))
			)
		end
	end

	TREE_ID += 1
	return {
		position = (bottom_box_cframe * CFrame.new(0, box_size_halved.y, 0)).Position,
		nodes = table.freeze(nodes),
		current_stock = node_count,
		max_stock = node_count,
		tree_id = TREE_ID,
	}
end

--[[
	Gives the closest empty node within the tree to the given position,
	alongside the distance between the node and the given position
]]
function object_tree.closest_empty_node(tree: Tree, position: vector): (Node, number)
	local nearest_node_dist = math.huge
	local nearest_node: Node

	for _, node in tree.nodes do
		if node.taken or node.takeable then
			continue
		end
		local supporter = node.supporter

		if supporter then
			if node.has_one_supporter then
				if not supporter.takeable then
					continue
				end
			else
				local are_supporting_nodes_taken = false

				for _, supporting_node in supporter do
					if supporting_node.taken then
						are_supporting_nodes_taken = true
						break
					end
				end

				if not are_supporting_nodes_taken then
					continue
				end
			end
		end
		local dist = vector.magnitude(node.position - position)

		if dist < nearest_node_dist then
			nearest_node_dist = dist
			nearest_node = node
		end
	end

	return nearest_node, nearest_node_dist
end

--[[
	Gives the closest node within the tree to the given position,
	alongside the distance between the node and the given position
]]
function object_tree.closest_node(tree: Tree, position: vector): (Node, number)
	local nearest_node_dist = math.huge
	local nearest_node: Node

	for _, node in tree.nodes do
		local dist = vector.magnitude(node.position - position)

		if dist < nearest_node_dist then
			nearest_node_dist = dist
			nearest_node = node
		end
	end

	return nearest_node, nearest_node_dist
end

--[[
	Marks the provided node within the object tree as empty
]]
function object_tree.mark_node_empty(tree: Tree, node: Node)
	local supporter = node.supporter
	node.takeable = false
	node.taken = false

	tree.current_stock -= 1

	if supporter then
		if node.has_one_supporter then
			supporter.takeable = false
		else
			-- checking if the supporting nodes for this node
			-- have nodes that are taken that they are supporting,
			-- if they dont have any we set "takeable" to true, otherwise false
			for _, supporting_node in supporter do
				local can_supporting_node_be_grabbed = true

				for _, node in supporting_node.supported :: { Node } do
					if node.taken then
						can_supporting_node_be_grabbed = false
						break
					end
				end

				supporting_node.takeable = can_supporting_node_be_grabbed
			end
		end
	end
end

--[[
	Marks the provided node within the object tree as taken
]]
function object_tree.mark_node_taken(tree: Tree, node: Node)
	local supporter = node.supporter
	node.takeable = true
	node.taken = true

	tree.current_stock += 1

	if supporter then
		if node.has_one_supporter then
			supporter.takeable = false
		else
			for _, supporting_node in supporter do
				supporting_node.takeable = false
			end
		end
	end
end

return table.freeze(object_tree)
