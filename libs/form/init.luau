
--[[
	form
	module for validating forms
]]

local random = require("@libs/random")

type function singleton_is_number(t)
	return if t.tag == "singleton" and type(t:value()) == "number" then
			t
		else
			nil
end

type function singleton_is_string(t)
	return if t.tag == "singleton" and type(t:value()) == "string" then
			t
		else
			nil
end

type function get_array_length(a): number?
	local has_iterated = false
	local highest_index = 0

	for index in a:properties() do
		index = index:value()
				
		if index > highest_index then
			highest_index = index
		end
		has_iterated = true
	end

	return if has_iterated then highest_index else nil
end

export type QuestionType = "MultipleChoice" | "Checkboxes" | "DateTime"
	| "Scale" | "Date" | "Time" | "Text"

type BoolOrRandom = boolean | random.Random

type Bonus = true | number

type StringOrStrings = { string } | string

export type QuestionId = number

type function range(t: type)
	local from_not_num_err = "field 'from' must be of type 'number'"
	local to_not_num_err = "field 'to' must be of type 'number'"
	local from = t:readproperty(types.singleton("from"))
	local to = t:readproperty(types.singleton("to")) 

	if from:is("singleton") and to:is("singleton") then
		local fromv = from:value()
		local tov = to:value()

		if type(fromv) ~= "number" then
			error(from_not_num_err)
		end

		if type(tov) ~= "number" then
			error(to_not_num_err)
		end

		if fromv > tov then
			error("field 'from' cannot be greater than field 'to'")
		end
	elseif not from:is("nil") and not from:is("number") then
		error(from_not_num_err)
	elseif not to:is("nil") and not to:is("number") then
		error(to_not_num_err)
	end

	return t
end

-- Question Bases

type BaseQuestionBase<TYPE, A, C, MAXL, MINL, F, T, B, R> = range<{
	max_len: MAXL,
	min_len: MINL,
	required: R,
	choices: C,
	type: TYPE,
	answer: A,
	bonus: B,
	from: F,
	to: T,
}>

type QuizQuestionBase<TYPE, A, C, MAXL, MINL, F, T, B = Bonus> = 
	| BaseQuestionBase<TYPE, A, C, MAXL, MINL, F, T, B, false?>
	| BaseQuestionBase<TYPE, A, C, MAXL, MINL, F, T, nil, true>

type QuestionBase<TYPE, A, C, MAXL, MINL, F, T> = BaseQuestionBase<TYPE, A, C, MAXL, MINL, F, T, nil, false?>

type function merge_table_and_string_singleton(t, s)
	local indexer_result = (t :: type):indexer().readresult
	local is_indexer_result_not_string = indexer_result.tag ~= "string"
	local len = get_array_length(t)
	local is_not_string = s.tag ~= "string"

	if is_not_string and is_indexer_result_not_string then
		t:setproperty(types.singleton(len + 1), s)
	end

	if is_not_string or is_indexer_result_not_string then
		t:setindexer(types.number, types.unionof(s, indexer_result))
	end

	return t
end

type function merge_iccc(ic: type, cc: type)
	if ic.tag == "union"and cc.tag == "union" then
		return ic
	end

	local is_ic_string = ic.tag == "string"
	local is_cc_string = ic.tag == "string"

	if is_ic_string and is_cc_string then
		return types.newtable(nil, {
			index = types.number,
			writeresult = cc,
			readresult = cc,
		})
	elseif 
		is_ic_string or singleton_is_string(ic) or 
		is_cc_string or singleton_is_string(cc) 
	then
		local union = types.unionof(ic, cc)
		return types.newtable(nil, {
			writeresult = union,
			readresult = union,
			index = types.number,
		})
	end

	local is_ic_table = ic.tag == "table"
	local is_cc_table = cc.tag == "table"

	if is_ic_table and is_cc_table then
		local new_array = types.newtable()
		local has_added = {}

		for index, value in ic:properties() do
			new_array:setproperty(index, value)
			table.insert(has_added, value)
		end
		local ic_len = #has_added

		for index, value in cc:properties() do
			new_array:setproperty(types.singleton(ic_len + index:value()), value)
			table.insert(has_added, value)
		end

		new_array:setindexer(index, result)
		return new_array
	elseif is_ic_table then
		return merge_table_and_string_singleton(ic, cc)
	elseif is_cc_table then
		return merge_table_and_string_singleton(cc, ic)
	else
		error("invalid type for either IC or CC")
	end
end

type function dont_allow_duplicates_in_choices_answer(choices_answer: type)
	local duplicate_val_from_other_err = "table '%*' has a duplicate of value '%*' at %*; previously defined in table '%*' at index %*"
	local duplicate_val_err = "table '%*' has a duplicate of value '%*' at %*; previously defined at index %*"
	local incorrect = choices_answer:readproperty(types.singleton("incorrect")) :: type 
	local correct = choices_answer:readproperty(types.singleton("correct")) :: type
	local incorrect_values = {}
	local correct_values = {}

	if incorrect.tag == "table" then
		for index, value in incorrect:properties() do
			value = value.read	
			local already_has = table.find(incorrect_values, value)
		
			if already_has then
				error(string.format(duplicate_val_err, "incorrect", value, index:value(), already_has))
			end
			table.insert(incorrect_values, value)
		end
	end

	if correct.tag == "table" then
		for index, value in correct:properties() do
			value = value.read
			local already_has = table.find(correct_values, value)
		
			if already_has then
				error(string.format(duplicate_val_err, "correct", value, index:value(), already_has))
			end
			table.insert(correct_values, value)
		end
	end

	if incorrect.tag == "table" and correct.tag == "table" then
		for index, value in incorrect_values do
			local correct_index = table.find(correct_values, value)
		
			if correct_index then
				error(string.format(duplicate_val_from_other_err, "incorrect", value, index, "correct", correct_index))
			end
		end

		for index, value in correct_values do
			local incorrect_index = table.find(correct_values, value)
		
			if incorrect_index then
				error(string.format(duplicate_val_from_other_err, "correct", value, index, "incorrect", incorrect_index))
			end
		end
	end

	return choices_answer
end

type ChoicesQuizQuestion<T, IC, CC, B> = QuizQuestionBase<T, dont_allow_duplicates_in_choices_answer<{
	read incorrect: IC,
	read correct: CC,
}>, merge_iccc<IC, CC>, nil, nil, nil, nil, B>

type ChoicesQuestion<T, C> = QuestionBase<T, nil, C, nil, nil, nil, nil>

-- Questions

export type MultipleChoiceQuestion<C = { string }> = ChoicesQuestion<"MultipleChoice", C>

export type MultipleChoiceQuizQuestion<IC = StringOrStrings, CC = StringOrStrings, B = Bonus> = ChoicesQuizQuestion<"MultipleChoice", IC, CC, B>

export type CheckboxesQuestion<C = { string }> = ChoicesQuestion<"Checkboxes", C>

export type CheckboxesQuizQuestion<IC = string, CC = string, B = Bonus> = ChoicesQuizQuestion<"Checkboxes", IC, CC, B>

export type TextQuizQuestion<A = string?, MINL = number?, MAXL = number?, B = Bonus> = QuizQuestionBase<"Text", A, nil, MINL, MAXL, nil, nil, B>

export type TextQuestion<MINL = number?, MAXL = number?> = QuestionBase<"Text", nil, nil, MINL, MAXL, nil, nil>

export type ScaleQuizQuestion<AF = number, AT = number, A = number, F = number, T = number, B = Bonus> = QuizQuestionBase<"Scale", range<{
	read from: F,
	read to: T,
}> | A, nil, nil, nil, F, T, B>

export type ScaleQuestion<F = number, T = number> = QuestionBase<"Scale", nil, nil, nil, nil, F, T>

export type TimeInfo<S = number, M = number, H = number> = {
	hour: H,
	sec: S,
	min: M,
}

--TODO: in future when number libterals exist use a type function for insuring a range for the day arg
export type DateInfo<D = number, M = number, Y = number> = {
	month: M,
	year: Y,
	day: D,
}

export type DateTimeInfo<
	S = number, MIN = number, H = number, 
	D = number, MONTH = number, Y = number
> = DateInfo<D, MONTH, Y> & TimeInfo<S, MIN, H>

export type DateTimeQuizQuestion<F = DateTimeInfo?, T = DateTimeInfo?, A = {
	from: DateTimeInfo,
	to: DateTimeInfo,
}?, B = Bonus> = QuizQuestionBase<"DateTime", A, nil, nil, nil, F, T, B>

export type DateTimeQuestion<F = DateTimeInfo?, T = DateTimeInfo?> = QuestionBase<"DateTime", nil, nil, nil, nil, F, T>

export type DateQuizQuestion<F = DateInfo?, T = DateInfo?, A = {
	from: DateInfo,
	to: DateInfo,
}?, B = Bonus> = QuizQuestionBase<"Date", A, nil, nil, nil, F, T, B>

export type DateQuestion<F = DateInfo?, T = DateInfo?> = QuestionBase<"Date", nil, nil, nil, nil, F, T>

export type TimeQuizQuestion<F = TimeInfo?, T = TimeInfo?, A = {
	from: TimeInfo,
	to: TimeInfo,
}?, B = Bonus> = QuizQuestionBase<"Time", A, nil, nil, nil, F, T, B>

export type TimeQuestion<F = TimeInfo?, T = TimeInfo?> = QuestionBase<"Time", nil, nil, nil, nil, F, T>

-- Question Unions

export type QuizQuestion = 
	| MultipleChoiceQuizQuestion 
	| CheckboxesQuizQuestion 
	| TextQuizQuestion 
	| ScaleQuizQuestion

export type Question =
	| MultipleChoiceQuestion
	| CheckboxesQuestion
	| TextQuestion
	| ScaleQuestion

export type MixedQuestion = 
	| QuizQuestion
	| Question

-- Question Responces

type QuestionResponceBase<T = QuestionType, R = string> = {
	question_name: string,
	responce: R,
	type: T,
}

export type MultipleChoiceQuestionResponce = QuestionResponceBase<"MultipleChoice", string>

export type CheckboxesQuestionResponce = QuestionResponceBase<"Checkboxes", { string }>

export type ScaleQuestionResponce = QuestionResponceBase<"Scale", number>

export type TextQuestionResponce = QuestionResponceBase<"Text", string>

export type QuestionResponce =
	| TextQuestionResponce
	| ScaleQuestionResponce
	| MultipleChoiceQuestionResponce
	| CheckboxesQuestionResponce

-- Form

type BaseFormConfig<APC, DBP, PTP, IQ, N> = {
	read award_partially_correct: APC,
	read default_bonus_points: DBP,
	read percent_to_pass: PTP,
	read is_quiz: IQ,
	read name: N,
}

type FormConfig<APC, IQ, N> = BaseFormConfig<APC, number?, number?, IQ, N >

type BaseFormInfo<APC, IQ, QL, N> = FormConfig<APC, IQ, N> & {
	read questions: QL,
}

-- TODO: convert to type function instead of union when type:issubtypeof() is added
export type FormInfo<N = string, QL = {}> =
	| BaseFormInfo<boolean?, false?, QL & { [string]: MixedQuestion }, N>
	| BaseFormInfo<boolean?, true, QL & { [string]: QuizQuestion }, N>

export type FormResponce<T = nil> = {
	question_responces: { QuestionResponce },
	info: T,
}

type RegisteredQuestionInfo = {
	read id: QuestionId,
	read name: string,
}

--[[
	choice buffer spec:
	1 byte id
	1 byte name len
	0..255 bytes for name
]]
--[[
	form responce buffer spec:
	1 bytes for info len
	0..255 bytes for info
	variable bytes for questions

	questions:
		1 byte question id

		checkboxes:
			1 byte for choice ids len
			variable bytes for choice ids

		multiple choice:
			1 byte for choice id

		scale:
			1 byte for position on scale selected

		text:
			2 bytes for len
			0..65_535 bytes for string
]]
type FormSerializerPrototype<F> = {
	--TODO: replace the any for the answer param with a type function
	--TODO: constraint Q with index<index<F, "questions">> when https://github.com/luau-lang/luau/issues/1825 is fixed
	record_question: <Q>(serializer: FormSerializer<F>, question: Q, answer: any) -> (),
	--[[
		Appends 
	]]
	write_info: (serializer: FormSerializer<F>, info: buffer) -> (),
	--[[
		Trims off empty unused bytes from the serializer's buffer, and gives a new buffer that has the exact size nessasary.
	]]
	trim: (serializer: FormSerializer<F>) -> buffer,
	__index: FormSerializerPrototype<F>,
}

type FormSerializer<F> = setmetatable<{
	-- info_len and offset are private 
	read info_len: number,
	read buffer: buffer,
	read offset: number,
	read form: F,
}, FormSerializerPrototype<F>>


type ChoiceQuestionProducerPrototype<Q> = {
	remove: (choice_producer: ChoiceQuestionProducer<Q>, choice: string) -> (),
	add: (choice_producer: ChoiceQuestionProducer<Q>, choice: string) -> (),
	finish: (choice_producer: ChoiceQuestionProducer<Q>) -> Q,
	__index: ChoiceQuestionProducerPrototype<Q>,
}

type ChoiceQuestionProducer<Q> = setmetatable<{
	question: Q,
}, ChoiceQuestionProducerPrototype<Q>>

type ChoiceQuizQuestionProducerPrototype<Q> = {
	find: (choice_producer: ChoiceQuestionProducer<Q>, choice: string) -> ("incorrect" | "correct")?,
	add_incorrect: (choice_producer: ChoiceQuestionProducer<Q>, choice: string) -> (),
	add_correct: (choice_producer: ChoiceQuestionProducer<Q>, choice: string) -> (),
	remove: (choice_producer: ChoiceQuestionProducer<Q>, choice: string) -> (),
	finish: (choice_producer: ChoiceQuizQuestionProducer<Q>) -> Q,
	__index: ChoiceQuizQuestionProducerPrototype<Q>,
}

type ChoiceQuizQuestionProducer<Q> = setmetatable<{
	--TODO: do some stuff for bonus with some basequestioninfo struct idk
	-- bonus: Bonus,
	question: Q,
}, ChoiceQuizQuestionProducerPrototype<Q>>

type MultipleChoiceQuizQuestionProducer = ChoiceQuizQuestionProducer<MultipleChoiceQuizQuestion>

type MultipleChoiceQuestionProducer = ChoiceQuestionProducer<MultipleChoiceQuestion>

type CheckboxesQuizQuestionProducer = ChoiceQuizQuestionProducer<CheckboxesQuizQuestion>

type CheckboxesQuestionProducer = ChoiceQuizQuestionProducer<CheckboxesQuestion>

--[[
	TODO: use a type function for the add/remove question returns,
		and remove add/remove returning any (this is currently because of recusrive type restrictions!! grr)
]]
type FormProducerPrototype<N, IQ, FRI> = {
	add_question: <QI>(editor: FormProducer<N, IQ, FRI>, name: string, info: QI) -> any,
	remove_question: (editor: FormProducer<N, IQ, FRI>, name: string) -> any,
	--TODO: replace brackets w type function based on IQ (is_quiz)
	--finish: (editor: FormProducer<N, IQ, FRI>) -> Form<N, IQ, {}, FRI>,
	__index: FormProducerPrototype<N, IQ, FRI>,
}

type FormProducer<N = string, IQ = false?, FRI = nil> = setmetatable<{
	--TODO: replace brackets w type function based on IQ (is_quiz)
	read form: BaseForm<N, IQ, {}>,
}, FormProducerPrototype<N, IQ, FRI>>

type BaseFormBufferInfo<SQC, SQ, IQ, IA, II> = {
	shuffle_question_choices: SQC, -- default false
	shuffle_questions: SQ, -- default false
	include_questions: IQ, -- default true
	include_answers: IA, -- default true unless IQ is false
	include_info: II, -- default true
	extra_size: number?,
}

export type FormBufferInfo = 
	| BaseFormBufferInfo<BoolOrRandom?, BoolOrRandom?, true?, boolean?, boolean?> 
	| BaseFormBufferInfo<false?, false?, false, false?, true> 

type FormPrototype<N, IQ, QL = {}, FRI = nil> = {
	grade: ((form: Form<N, IQ, QL, FRI>, responce: FormResponce<FRI>) -> (boolean, number, { [QuestionResponce]: boolean })) &
		((form: Form<N, IQ, QL, FRI>, responce: buffer) -> (boolean, number, { [QuestionId]: boolean })),
	to_buffer: (form: Form<N, IQ, QL, FRI>, buffer_info: FormBufferInfo) -> buffer,
	--TODO: constrain QN to keyof<QL>
	get_question: (<QN>(form: Form<N, IQ, QL, FRI>, name: QN) -> index<QL, QN> & RegisteredQuestionInfo) &
		--TODO: replace the any return with a type function when interger literals are added
		(<QI>(form: Form<N, IQ, QL, FRI>, id: QI) -> any),
	get_serializer:(form: Form<N, IQ, QL, FRI>) -> FormSerializer<Form<N, IQ, QL, FRI>>,
	--[[
		Creates a FormProducer for editing this form, useful for making UIs to edit forms. 
	]]
	edit: (form: Form<N, IQ, QL, FRI>) -> FormProducer<N, IQ, FRI>,
	__index: FormPrototype<N, IQ, QL, FRI>,
}

type BaseForm<N, IQ, QL> = BaseFormInfo<boolean, IQ, { MixedQuestion & RegisteredQuestionInfo }, N> & {
	read max_responce_buffer_size: number,
	read can_fully_autograde: boolean,
	read min_points: number,
}

-- TODO: make into type function so is_quiz can be properly inferred 
type Form<N = string, IQ = boolean, QL = {}, FRI = nil> = setmetatable<BaseForm<N, IQ, QL>, FormPrototype<N, QL, FRI>>

type Export = {
	--[[
		Creates a FormProducer for creating a form using a config, useful for making UIs to create forms. 
	]]
	build: <FRI, APC, QL, IQ, N>(config: FormConfig<APC, IQ, N>) -> FormProducer<N, IQ, FRI>,
	--[[
		Registers a form so it can be used for grading
	]]
	register: (<N, IQ, QL, FRI>(info: FormInfo<N, QL>) -> Form<N, IQ, QL, FRI>) &
		((form_buffer: buffer) -> Form),
	--[[
		Returns a buffer with the info included in a responce buffer if any.
	]]
	get_info_from_repsonce_buffer: (responce_buffer: buffer) -> buffer?,
}

-- qquestion is quizquestion its just quiz makes the variable too long
local ERR_QQUESTION_FIELD_UNDEFINED = "[FORM]: question '%*' is a quiz '%*' question without the '%*' field defined in the answer table"
local ERR_CFG_FIELD_RANGE = "[FORM]: config field '%*' cannot be %* than %*"
local DEFAULT_PERCENT_TO_PASS = 70
local POINTS_PER_QUESTION = 100
local DEFAULT_BONUS_POINTS = 50
local FORMAT = string.format

local function SET_READ_KEY<T, K>(t: T, k: K & keyof<T>, v: index<T, K>)
	(t :: any)[k] = v
end

local function VALIDATE_FORM_CONFIG(
	config: FormConfig<boolean?, boolean?, string>
): BaseFormConfig<boolean, number, number, boolean, string>
	local default_bonus_points = config.default_bonus_points
	local percent_to_pass = config.percent_to_pass

	if default_bonus_points and default_bonus_points < 1 then
		error(FORMAT(ERR_CFG_FIELD_RANGE, "default_bonus_points", 1), 3)	
	end

	if percent_to_pass then
		if percent_to_pass < 1 then
			error(FORMAT(ERR_CFG_FIELD_RANGE, "percent_to_pass", 1), 3)	
		elseif percent_to_pass > 100 then
			error(FORMAT(ERR_CFG_FIELD_RANGE, "percent_to_pass", 100), 3)
		end
	end

	return {
		default_bonus_points = default_bonus_points or DEFAULT_BONUS_POINTS,
		award_partially_correct = config.award_partially_correct ~= nil,
		percent_to_pass = percent_to_pass or DEFAULT_PERCENT_TO_PASS,
		is_quiz = config.is_quiz ~= nil,
		name = config.name,
		--[[
			preallocating the other fields nessasary, as these are going to be set later on
			by either a FormProducer or form.register
		]]
		max_responce_buffer_size = nil,
		can_fully_autograde = nil,
		min_points = nil,
		questions = nil,
	}
end

local function WRITE_U8(b: buffer, offset: number, n: number): number
	buffer.writeu8(b, offset, n)
	return offset + 1
end

local function WRITE_U16(b: buffer, offset: number, n: number): number
	buffer.writeu16(b, offset, n)
	return offset + 2
end

local function WRITE_SHORT_STRING(b: buffer, offset: number, s: string): number
	offset = WRITE_U8(b, offset, #s)
	buffer.writestring(b, offset, s)
	return offset + #s 
end

local function WRITE_LONG_STRING(b: buffer, offset: number, s: string): number
	offset = WRITE_U16(b, offset, #s)
	buffer.writestring(b, offset, s)
	return offset + #s
end

local function WRITE_BOOLEAN(b: buffer, offset: number, v: boolean?): number
	return WRITE_U8(b, offset, if v then 1 else 0)
end

-- this guy doesnt inline so native it will be 
@native
local function WRITE_CHOICES(
	b: buffer, offset: number, choices: { string },
	answer_ids: { [number]: string }
): number
	offset = WRITE_U8(b, offset, #choices - 1)
	offset += 1

	for _, choice in choices do
		buffer.writeu8(b, offset, table.find(answer_ids, choice) :: any)
		offset = WRITE_SHORT_STRING(b, offset + 1, choice)
	end
	return offset
end

local function SHUFFLE<V>(t: { V }, bool_or_random: BoolOrRandom?)
	if bool_or_random == true then
		random.shuffle(t)
	elseif bool_or_random then
		bool_or_random:shuffle(t)
	end
end

local function TYPE_TO_NUM(type: QuestionType): number
	return if type == "MultipleChoice" then
			4
		elseif type == "Checkboxes" then
			3
		elseif type == "Scale" then
			2
		else
			1
end

local function FREEZE_IF_NOT_FROZEN<T>(t: T & {}): T
	if not table.isfrozen(t) then
		table.freeze(t)
	end
	return t
end

-- using the prototype types no workey :(
local form_serializer = {} :: getmetatable<FormSerializer<{}>>

function form_serializer.record_question(serializer, question, answer)
	local offset = serializer.offset

end

function form_serializer.write_info(serializer, info)
	local size = buffer.len(info)
	local b = serializer.buffer

	if size > 256 then
		error("[FORM]: info buffer len cannot be greater than 256", 2)
	end
	
	serializer.info_size = size
	buffer.writeu8(b, 0, size)
	buffer.copy(b, 1, info)
end

function form_serializer.trim(serializer)

end

local form_producer = {} :: getmetatable<FormProducer>

function form_producer.remove_question(producer)
	
end

function form_producer.add_question(producer)
	
end

function form_producer.finish(producer)
	-- free the entire producer table and return it
	return producer
end

local form = {} :: Export

@native
function form.get_info_from_repsonce_buffer(responce_buffer)
	
end

function form.get_question(form, name_or_id)
	if type(name_or_id) == "number" then
		for _, question in form.questions do
			if question.id == name_or_id then
				return question
			end
		end
	else
		for _, question in form.questions do
			if question.name == name_or_id then
				return question
			end
		end
	end

	return nil :: any
end

local function register_info(info: FormInfo): Form
	local default_bonus_points = info.default_bonus_points or DEFAULT_BONUS_POINTS
	-- this array is too complex to type here so its just becoming any
	local questions_array = {} :: { any }
	local can_fully_autograde = true
	local required_points = 0
	local next_id = 0

	for name, question: MixedQuestion in info.questions do
		local answer = question.answer
		local question_type = question.type

		if question_type == "Scale" then
			if type(answer) == "table" then
				local from = answer.from
				local to = answer.to

				if to and not from then
					error(FORMAT(ERR_QQUESTION_FIELD_UNDEFINED, name, question_type, "from"))
				elseif from and not to then
					error(FORMAT(ERR_QQUESTION_FIELD_UNDEFINED, name, question_type, "to"))
				end

				FREEZE_IF_NOT_FROZEN(answer)
			else
				question.answer = table.freeze({
					from = answer,
					to = answer,
				})
			end
		elseif type(answer) == "table" then
			local incorrect = answer.incorrect
			local correct = answer.correct
	
			if incorrect and not correct then
				error(FORMAT(ERR_QQUESTION_FIELD_UNDEFINED, name, question_type, "correct"))
			elseif correct and not incorrect then
				error(FORMAT(ERR_QQUESTION_FIELD_UNDEFINED, name, question_type, "incorrect"))
			end
			--TODO: need to reflect the answers_ids array in the type
			local answer_ids = table.move(
				incorrect, 1, #incorrect, #correct + 1, 
				table.clone(correct)
			)

			--[[
				TODO: need to reflect that after registering the choices field isnt nil anymore
				(waiting for type:issubtypeof() to be added so writing the type function for the form object isnt a pain)
			]]
			question.choices = table.clone(answer_ids)
			question.answer_ids = answer_ids
			FREEZE_IF_NOT_FROZEN(incorrect)
			FREEZE_IF_NOT_FROZEN(correct)
			FREEZE_IF_NOT_FROZEN(answer)
		elseif question.choices then
			question.answer_ids = table.clone(question.choices)
		end

		if question.bonus == true then
			question.bonus = default_bonus_points
		elseif not question.bonus then
			question.bonus = 0
		elseif question.required then
			required_points += POINTS_PER_QUESTION
		end

		if question.type == "Text" then
			can_fully_autograde = false
		end

		table.insert(questions_array, question)
		question.id = next_id
		question.name = name
		table.freeze(question)
		next_id += 1
	end

	if info.award_partially_correct == nil then
		info.award_partially_correct = true
	end

	info.min_points = (required_points * (info.percent_to_pass or 70)) // 100
	info.can_fully_autograde = can_fully_autograde
	info.questions = questions_array
	return table.freeze(info)
end

@native
local function register_buffer(b: buffer): Form
	
end

--TODO: add overload for registering from a buffer
function form.register(info_or_buffer)
	if type(info_or_buffer) == "buffer" then
		return register_buffer(info_or_buffer)
	else
		return register_info(info_or_buffer)
	end
end

--[[
	form buffer spec:
	1 byte is_quiz
	1 byte can_fully_autograde
	1 byte award_partially_correct
	2 bytes min_points
	1 byte questions len
	1 byte name len
	0..255 bytes for name

	questions:
		1 byte id
		1 byte type
		1 byte is_quiz 
		1 byte required
		1 byte bonus
		1 byte name len
		0..255 bytes for name

		multiple choice & checkboxes:
			if is_quiz then
				1 byte incorrect len
				variable bytes for incorrect choices
				1 byte correct len
				variable bytes for correct choices
			else
				1 byte choices len
				variable bytes for choices

		scale:
			1 byte from (the starting point on the scale)
			1 byte to (the ending point on the scale)

			if is_quiz then
				1 byte for the answers from
				1 byte for the answers to

		text:
			2 bytes min len
			2 bytes max len

			if is_quiz then
				2 bytes answer len
				0..65_535 bytes for answer
]]
@native
function form.to_buffer(form, info)
	local questions = form.questions
	local include_questions = true
	local include_answers = true
	local include_info = true
	local offset = 0
	local size = 0

	if info then
		if info.include_questions ~= nil then
			include_questions = info.include_questions
		end

		if include_questions and info.include_answers ~= nil then
			include_answers = info.include_answers
		end

		if info.include_info ~= nil then
			include_info = info.include_info
			size += #form.name + 7
		end

		if info.extra_size then
			offset = info.extra_size
			size += offset
		end
	end

	if include_questions then
		local shuffle_question_choices = info and include_questions and info.shuffle_question_choices
		SHUFFLE(questions, info and info.shuffle_questions)

		for _, question in questions do
			local question_type: QuestionType = question.type
			local answer = include_answers and question.answer

			size += #question.name + 6

			if question_type == "Scale" then
				size += 2

				if answer then
					size += 2
				end
			elseif question_type == "Text" then
				size += 4

				if answer then
					size += #answer + 2
				end
			else
				local choices = question.choices
				size += (#choices * 2) + 1

				SHUFFLE(choices, shuffle_question_choices)

				for _, choice in choices do
					size += #choice
				end

				if answer then
					size += 1
				end
			end
		end
	end

	local b = buffer.create(size)
	
	if include_info then
		offset = WRITE_BOOLEAN(b, offset, form.is_quiz)
		offset = WRITE_BOOLEAN(b, offset, form.can_fully_autograde)
		offset = WRITE_BOOLEAN(b, offset, form.award_partially_correct)
		offset = WRITE_U16(b, offset, form.min_points)
		offset = WRITE_U8(b, offset, #questions)
		offset = WRITE_SHORT_STRING(b, offset, form.name)
	end

	if include_questions then
		for _, question in questions do
			local answer = include_answers and question.answer
			local question_type = question.type

			offset = WRITE_U8(b, offset, question.id)
			offset = WRITE_U8(b, offset, TYPE_TO_NUM(question_type))
			offset = WRITE_BOOLEAN(b, offset, answer ~= nil)
			offset = WRITE_BOOLEAN(b, offset, question.required)
			offset = WRITE_U8(b, offset, question.bonus)
			offset = WRITE_SHORT_STRING(b, offset + 1, question.name)

			if question_type == "Scale" then
				offset = WRITE_U8(b, offset, question.from)
				offset = WRITE_U8(b, offset, question.to)

				if answer then
					offset = WRITE_U8(b, offset, answer.from)
					offset = WRITE_U8(b, offset, answer.to)
				end
			elseif question_type == "Text" then
				--[[
					min/max len wont be nil because when registering if the form info doesnt have them defined
					they get defined to the default min maxes
				]]
				offset = WRITE_U16(b, offset, question.min_len)
				offset = WRITE_U16(b, offset, question.max_len)

				if answer then
					offset = WRITE_LONG_STRING(b, offset, answer)
				end
			else
				local answer_ids = answer.answer_ids

				if answer then
					offset = WRITE_CHOICES(b, offset, answer.incorrect, answer_ids)
					offset = WRITE_CHOICES(b, offset, answer.correct, answer_ids)
				else
					offset = WRITE_CHOICES(b, offset, answer.choices, answer_ids)
				end
			end
		end
	end

	return b
end

function form.serializer(form)
	return setmetatable({
		buffer = buffer.create(form.max_responce_buffer_size),
		info_len = 0,
		offset = 256,
		form = form,
	}, form_serializer)
end

@native
local function grade_buffer(
	form: Form, responce: buffer
): (boolean, number, { [QuestionId]: boolean })
	
end

local function grade_table(
	form: Form, responce: FormResponce
): (boolean, number, { [string]: boolean })
	
end

function form.grade(form, responce)
	if type(responce) == "buffer" then
		return grade_buffer(form, responce)
	else
		return grade_table(form, responce)
	end
end

function form.build(config)
	return table.freeze(setmetatable({
		form = VALIDATE_FORM_CONFIG(config)
	}, form_producer))
end

function form.edit(form)
	local questions = table.clone(form.questions)
	local clone = table.clone(form)
	clone.questions = questions

	for index, question in questions do
		local question_clone = table.clone(question)

		if question_clone.type == "Scale" then
			question_clone.answer = table.clone(question_clone.answer)
		elseif type(question_clone.answer) == "table" then
			local answer = question_clone.answer 

			question_clone.answer = {
				incorrect = table.clone(answer.incorrect),
				correct = table.clone(answer.correct),
			}
			question_clone.answer_ids = table.clone(question_clone.answer_ids)
		end

		if question_clone.choices then
			question_clone.choices = table.clone(question_clone.choices)
		end

		questions[index] = question_clone
	end

	return table.freeze(setmetatable({
		form = clone
	}, form_producer))
end

do

	form_serializer.__index = form_serializer
	form_producer.__index = form_producer
	table.freeze(form_serializer)
	table.freeze(form_producer)

end

return table.freeze(form)
