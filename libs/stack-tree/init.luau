--!native

--[[
	stack tree
	library for generating tree structures for nodes on a shelf
	to prevent floating nodes from ever happening
]]

local random = require("@libs/random")

export type FaceTowardsSide = "Front" | "Back" | "Left" | "Right"
-- TaperType names are referring to roof types, ie bloxburg roof types
export type TaperType = "Pyramid" | "Slope" | "Flat" | "Hip"

type BaseNode<HOS, S, N> = {
	--[[
		Indicates if this node can be grabbed, as in there are no taken nodes above this node and this node itself is also taken.
	]]
	takeable: boolean,
	--[[
		Indicates if the node has only a single supporter, this is purely internal
		and only used by `stack_tree.closest_empty_node`,
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

export type Tree = {
	current_stock: number,
	max_stock: number,
	position: vector,
	nodes: { Node },
}

type BaseRandomRotationInfo<RRN, RRMM> = {
	-- if set it can only randomly rotate the nodes within the range given
	random_rotation_min_max: RRMM,
	randomly_rotate_nodes: RRN,
}

type RandomRotationInfo =
	| BaseRandomRotationInfo<true, NumberRange?>
	| BaseRandomRotationInfo<false, nil>

type BaseTaperInfo<T, TTLTT, FTTS> = {
	-- This option will only work if TaperType == "Slope" or "Hip", where it will make the slope face that side
	face_taper_towards_side: FTTS?,
	-- If given BoxFill will only taper the the layers after the Index (TotalLayers - TotalTopLayersToTaper)
	-- NOTE: if TotalLayers - TotalTopLayersToTaper is not greater than 1 then
	-- BoxFill will error as indexes cant be less than 1
	-- and you cant taper the first layer
	total_top_layers_to_taper: TTLTT,
	taper_type: T,
}

type TaperInfo =
	| BaseTaperInfo<"Slope", number?, FaceTowardsSide>
	| BaseTaperInfo<"Hip", number?, FaceTowardsSide>
	| BaseTaperInfo<"Pyramid", number?, nil>
	| BaseTaperInfo<"Flat"?, nil, nil>

export type StackFillInfo = RandomRotationInfo & TaperInfo & {
	node_rotation_offset: vector?,
	padding: (Vector2 | vector)?,
	max_nodes_xyz: vector?,
	taper_type: TaperType?,
	should_stack: boolean?,
	box_cframe: CFrame?,
	node_size: vector,
	box_size: vector,
}

type NodeConnector = (
	node_cframe: CFrame,
	node_size: vector,
	layer_below: { Node },
	face_towards_side: FaceTowardsSide
) -> { Node }

type LayerEditor = (
	bottom_box_cframe: CFrame,
	box_size: vector,
	node_size: vector,
	index: number,
	face_towards_side: FaceTowardsSide,
	half_box_size: vector
) -> (CFrame, vector)

type TaperTransformer = {
	read node_connector: NodeConnector,
	read layer_editor: LayerEditor,
}

local DEFUALT_RANDOM_ROTATE_MIN_MAX = NumberRange.new(0, 10)

local function GET_NODES_CLOSEST_TO_POSITION(
	previous_layer: { Node }, position: vector, node_amount: number
): { Node }
	local nodes = table.create(node_amount)

	for index = 1, node_amount do
		local closest_magnitude = math.huge
		local closest_node: Node

		for _, node in previous_layer do
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

local function GET_POSITION_OF_NODE_BELOW(node_cframe: CFrame, node_size: vector): vector
	return (node_cframe * CFrame.new(0, -node_size.y, 0)).Position
end

local FLAT_NODE_CONNECTOR: NodeConnector = function(node_cframe, node_size, layer_below)
	local below_position = GET_POSITION_OF_NODE_BELOW(node_cframe, node_size)
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

local FLAT_TAPER_TRANSFORMER = table.freeze({
	layer_editor = function(bottom_box_cframe, box_size)
		return box_size, bottom_box_cframe
	end,
	node_connector = FLAT_NODE_CONNECTOR,
}) :: TaperTransformer

local TAPER_TRANSFORMERS: { [TaperType]: TaperTransformer } = table.freeze({
	Pyramid = table.freeze({
		node_connector = function(node_cframe, node_size, previous_layer)
			return GET_NODES_CLOSEST_TO_POSITION(
				previous_layer,
				GET_POSITION_OF_NODE_BELOW(node_cframe, node_size),
				4
			)
		end,
		layer_editor = function(bottom_box_cframe, box_size, node_size, index)
			return bottom_box_cframe,
				box_size - vector.create(node_size.x * index, 0, node_size.z * index)
		end,
	}),

	Slope = table.freeze({
		layer_editor = function(bottom_box_cframe, box_size, node_size, index, taper_towards_side, box_size_halved)
			if taper_towards_side == "Front" then
				local layer_cframe = bottom_box_cframe * CFrame.new(0, 0, -box_size_halved.z)

				return layer_cframe * CFrame.new(0, 0, box_size.z / 2),
					box_size - vector.create(0, 0, node_size.z * index)
			elseif taper_towards_side == "Right" then
				local layer_cframe = bottom_box_cframe * CFrame.new(box_size_halved.x, 0, 0)

				return layer_cframe * CFrame.new(-box_size.x / 2, 0, 0),
					box_size - vector.create(node_size.x * index, 0, 0)
			elseif taper_towards_side == "Left" then
				local layer_cframe = bottom_box_cframe * CFrame.new(-box_size_halved.x, 0, 0)

				return layer_cframe * CFrame.new(box_size.x / 2, 0, 0),
					box_size - vector.create(node_size.x * index, 0, 0)
			else -- back
				local layer_cframe = bottom_box_cframe * CFrame.new(0, 0, box_size_halved.z)

				return layer_cframe * CFrame.new(0, 0, -box_size.z / 2),
					box_size - vector.create(0, 0, node_size.z * index)
			end
		end :: any,
		--[[
			slope is basically the same as flat, as in theres always going to be a node directly below any node
			so it just uses the same node connector as flat
		]]
		node_connector = FLAT_NODE_CONNECTOR,
	}),

	Hip = table.freeze({
		node_connector = function(node_cframe, node_size, previous_layer, taper_towards_side)
			local negative_node_size = -node_size
			local approximate_below_cframe_offset = if taper_towards_side == "Right" or taper_towards_side == "Left" then
					CFrame.new(0, negative_node_size.y, negative_node_size.z))
				else
					CFrame.new(negative_node_size.x, negative_node_size.y, 0))

			return GET_NODES_CLOSEST_TO_POSITION(
				previous_layer, (node_cframe * approximate_below_cframe_offset).Position, 2
			)
		end,
		layer_editor = function(bottom_box_cframe, box_size, node_size, index, taper_towards_side)
			local sub_vector = if taper_towards_side == "Front" or taper_towards_side == "Back" then
					vector.create(node_size.x * index, 0, 0)
				else
					-- right and left
					vector.create(0, 0, node_size.z * index)

			return bottom_box_cframe, box_size - sub_vector
		end,
	} :: TaperTransformer),

	Flat = FLAT_TAPER_TRANSFORMER,
}) :: any

local stack_tree = {}

local function get_node_cframe(
	layer_cframe: CFrame, x: number, z: number,
	diff_x: number, diff_z: number,
	node_rotation_offset: CFrame
): CFrame
	return (layer_cframe * CFrame.new(x - diff_x, 0, z - diff_z)) * node_rotation_offset
end

--[[
	returns (layer_cframe, steps, diff_x, diff_z )
]]
local function get_layer_info(
	node_size: vector, half_node_size: vector,
	half_node_height: number, layer_size: vector,
	bottom_box_cframe: CFrame, previous_index: number
): (CFrame, number, number, number, number)
	local offset_cframe = CFrame.new(0, (node_size.y * previous_index) + half_node_height, 0)
	local size_diff = (layer_size / 2) - half_node_size
	local steps = layer_size - node_size

	return bottom_box_cframe * offset_cframe,
		steps.x,
		steps.z,
		size_diff.x,
		size_diff.z
end

local function get_taper_transformer(info: StackFillInfo): TaperTransformer
	local taper_type = info.taper_type

	if taper_type then
		local transformer = TAPER_TRANSFORMERS[taper_type]

		if transformer then
			return transformer
		else
			error(`[STACK TREE]: no taper transformer exists for string '{taper_type}'`)
		end
	else
		return FLAT_TAPER_TRANSFORMER
	end
end

local function get_node_rotation_offset(info: StackFillInfo): CFrame
	local node_rotation_offset = info.node_rotation_offset

	return if node_rotation_offset then
			CFrame.Angles(
				math.rad(node_rotation_offset.x),
				math.rad(node_rotation_offset.y),
				math.rad(node_rotation_offset.z)
			)
		else
			CFrame.identity
end

local function get_padding(info: StackFillInfo): vector
	local padding = info.padding

	return if padding then
			-- Vector2 has lowercase x & y properties, theyre just "deprecated"
			vector.create((padding :: any).x, (padding :: any).y, 0)
		else
			vector.zero
end

function stack_tree.generate(info: StackFillInfo): Tree
	local taper_towards_side = info.face_taper_towards_side or "Back"
	local total_top_layers_to_taper = info.total_top_layers_to_taper
	local node_rotation_offset = get_node_rotation_offset(info)
	local box_cframe = info.box_cframe or CFrame.identity
	local starting_box_size = info.box_size
	local padding = get_padding(info)

	local box_size = starting_box_size - padding
	local node_size = info.node_size + padding

	if node_size.x > box_size.x or node_size.y > box_size.y or node_size.z > box_size.z then
		error("[STACK TREE]: 'node_size' cannot be greater than 'box_size'")
	end

	-- calculating the most amount of nodes that can fit within the given box size
	local nodes_per_side = box_size // node_size

	if nodes_per_side.x < 1 or nodes_per_side.y < 1 or nodes_per_side.z < 1 then
		error("[STACK TREE]: cannot fit a single node into the given 'box_size'")
	end

	if info.max_nodes_xyz then
		nodes_per_side = vector.clamp(nodes_per_side, vector.one, info.max_nodes_xyz)
	end

	box_size = nodes_per_side * node_size

	local bottom_box_cframe = box_cframe * CFrame.new(0, -starting_box_size.y / 2, 0)
	local total_layers = if info.should_stack then nodes_per_side.y else 1
	local half_nodes_size = node_size / 2
	local half_nodes_height = half_nodes_size.y
	local taper_starting_index = 2

	if total_top_layers_to_taper then
		taper_starting_index = total_layers - total_top_layers_to_taper

		if 2 > taper_starting_index then
			error("[STACK TREE]: 'total_layers' - 'total_top_layers_to_taper' is less than 2, cannot start taper below 2")
		end
	end

	local transformer = get_taper_transformer(info)
	local layer_editor = transformer.layer_editor
	local node_connector = FLAT_NODE_CONNECTOR
	local half_box_size = box_size / 2
	local node_size_x = node_size.x
	local node_size_z = node_size.z
	local previous_layer: { Node }
	local nodes = {} :: { Node }
	local node_count = 1

	do
		local layer_cframe, steps_x, steps_z, diff_x, diff_z =	get_layer_info(
			node_size, half_nodes_size, half_nodes_height,
			box_size, bottom_box_cframe, 0
		)
		local layer = table.create(steps_x * steps_z)

		--[[
			using -0.001 as 1 has an offset that doesn't correctly
			center cframes properly, and -0.001 because the
			minimum amount you can move a part/model is by 0.001
		]]
		for x = -0.001, steps_x, node_size_x do
			for z = -0.001, steps_z, node_size_z do
				local node_cframe = get_node_cframe(layer_cframe, x, z, diff_x, diff_z, node_rotation_offset)

				layer[node_count] = {
					position = node_cframe.Position,
					cframe = node_cframe,
					takeable = false,
					taken = true,
				}
				node_count += 1
			end
		end

		previous_layer = layer
	end

	table.move(previous_layer, 1, node_count, 1, nodes)

	if total_layers ~= 1 then
		local previous_layer_index = 1
		local layer_size = box_size

		for layer_index = 2, total_layers do
			local layer_cframe, steps_x, steps_z, diff_x, diff_z = get_layer_info(
				node_size, half_nodes_size, half_nodes_height,
				layer_size, bottom_box_cframe, previous_layer_index
			)
			local layer_node_count = steps_x * steps_z

			if layer_node_count < 1 then
				break
			end

			local layer = table.create(layer_node_count) :: { Node }
			local node_index = 1

			-- cannot do >= because otherwise itll taper for an extra layer
			if layer_index > taper_starting_index then
				layer_cframe, layer_size = layer_editor(
					layer_cframe, layer_size, node_size, previous_layer_index,
					taper_towards_side :: any, half_box_size
				)
				node_connector = transformer.node_connector
			end

			for x = -0.001, steps_x, node_size_x do
				for z = -0.001, steps_z, node_size_z do
					local node_cframe = get_node_cframe(layer_cframe, x, z, diff_x, diff_z, node_rotation_offset)
					local supporters = node_connector(node_cframe, node_size, previous_layer, taper_towards_side :: any)
					local has_one_supporter = not supporters[2]
					local node = {
						supporter = if has_one_supporter then supporters[1] else supporters,
						has_one_supporter = has_one_supporter,
						position = node_cframe.Position,
						cframe = node_cframe,
						takeable = false,
						taken = true,
					}

					for _, supporter_node in supporters do
						local supported = supporter_node.supported

						if supported then
							table.insert(supported, node)
						else
							supporter_node.supported = { node }
						end
					end

					layer[node_index] = node
					node_index += 1
				end
			end

			table.move(layer, 1, layer_node_count, node_count + 1, nodes)
			previous_layer_index = layer_index
			node_count += layer_node_count
			previous_layer = layer
		end
	end

	-- setting all the nodes at the top to be able to be taken
	for _, node in previous_layer do
		node.takeable = true
	end

	if info.randomly_rotate_nodes then
		local random_rotation_min_max = info.random_rotation_min_max
			or DEFUALT_RANDOM_ROTATE_MIN_MAX
		local min = random_rotation_min_max.Min
		local max = random_rotation_min_max.Max

		for _, node in nodes do
			node.cframe *= CFrame.Angles(
				math.rad(random.float(min, max)),
				math.rad(random.float(min, max)),
				math.rad(random.float(min, max))
			)
		end
	end

	return {
		position = (bottom_box_cframe * CFrame.new(0, half_box_size.y, 0)).Position,
		nodes = table.freeze(nodes),
		current_stock = node_count,
		max_stock = node_count,
	}
end

--[[
	Returns the closest empty node within the tree to the position, and the nodes distance from position.
]]
function stack_tree.closest_empty_node(tree: Tree, position: vector): (Node, number)
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
function stack_tree.closest_node(tree: Tree, position: vector): (Node, number)
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
	Marks the provided node within the node tree as empty
]]
function stack_tree.mark_node_empty(tree: Tree, node: Node)
	local supporter = node.supporter
	node.takeable = false
	node.taken = false

	tree.current_stock -= 1

	if supporter then
		if node.has_one_supporter then
			supporter.takeable = false
		else
			--[[
				checking if the supporting nodes for this node
				have nodes that are taken that they are supporting,
				if they don't have any we set "takeable" to true, otherwise false
			]]
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
	Marks the provided node within the node tree as taken
]]
function stack_tree.mark_node_taken(tree: Tree, node: Node)
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

function stack_tree.is_full(tree: Tree): boolean
	return tree.current_stock == tree.max_stock
end

return table.freeze(stack_tree)
