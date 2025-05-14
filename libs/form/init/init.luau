
--[[
	form
	module for validating forms
]]

local random = require("../random")

export type QuestionType = "MultipleChoice" | "Text" | "Scale" | "Checkboxes"

type BoolOrRandom = boolean | random.Random

type function Range(t: type)
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

type BaseQuestionBase<TYPE, A, C,  MAXL, MINL, F, T, B, R> = Range<{
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

type QuizQuestionBase<TYPE, A, C, MAXL, MINL, F, T> = 
	| BaseQuestionBase<TYPE, A, C, MAXL, MINL, F, T, number | true, false>
	| BaseQuestionBase<TYPE, A, C, MAXL, MINL, F, T, nil, true>

type QuestionBase<TYPE, A, C, MAXL, MINL, F, T> = BaseQuestionBase<TYPE, A, C, MAXL, MINL, F, T, nil, false?>

type AnswersOnlyQuizQuestionBase<TYPE, A> = QuizQuestionBase<TYPE, A, nil, nil, nil, nil, nil>

-- Questions

export type MultipleChoiceQuestion = QuestionBase<"MultipleChoice", nil, { string }, nil, nil, nil, nil>

export type MultipleChoiceQuizQuestion = AnswersOnlyQuizQuestionBase<"MultipleChoice", {
	incorrect: { string },
	correct: { string }
}>

export type CheckboxesQuestion = QuestionBase<"Checkboxes", nil, { string }, nil, nil, nil, nil>

export type CheckboxesQuizQuestion = AnswersOnlyQuizQuestionBase<"Checkboxes", {
	incorrect: { string },
	correct: { string },
}>

export type TextQuizQuestion = QuizQuestionBase<"Text", string, nil, number?, number?, nil, nil>

export type TextQuestion = QuestionBase<"Text", nil, nil, number?, number?, nil, nil>

export type ScaleQuizQuestion<F = number, T = number> = QuizQuestionBase<"Scale", Range<{
	read from: F,
	read to: T,
}> | number, nil, nil, nil, number, number>

export type ScaleQuestion = QuestionBase<"Scale", nil, nil, nil, nil, number, number>

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

type BaseFormInfo<APC, IQ, QL, N> = {
	read default_bonus_points: number?,
	read award_partially_correct: APC,
	read percent_to_pass: number?,
	read questions: QL,
	read is_quiz: IQ,
	read name: N,
}

-- TODO: convert to type function instead of union when type:issubtypeof() is added
export type FormInfo<N = string, QL = {}> =
	| BaseFormInfo<boolean?, false?, QL & { [string]: MixedQuestion }, N>
	| BaseFormInfo<boolean?, true, QL & { [string]: QuizQuestion }, N>

type QuestionId = number

type RegisteredQuestionInfo = {
	read id: QuestionId,
	read name: string,
}

export type FormResponce<T = nil> = {
	question_responces: { QuestionResponce },
	info: T,
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
	write_info: (serializer: FormSerializer<F>, info: buffer) -> (),
	finish: (serializer: FormSerializer<F>) -> buffer,
	__index: FormSerializerPrototype<F>,
}

type FormSerializer<F> = setmetatable<{
	-- info_len and offset are private 
	read info_len: number,
	read buffer: buffer,
	read offset: number,
	read form: F,
}, FormSerializerPrototype<F>>

type BaseFormBufferInfo<SQC, SQ, IQ, IA, II> = {
	shuffle_question_choices: SQC, -- default false
	shuffle_questions: SQ, -- default false
	include_questions: IQ, -- default true
	include_answers: IA, -- default true unless IQ is false
	include_info: II, -- default true
}

type FormBufferInfo = 
	| BaseFormBufferInfo<BoolOrRandom?, BoolOrRandom?, true?, boolean?, boolean?> 
	| BaseFormBufferInfo<false?, false?, false, false?, true> 

type FormPrototype<N = string, QL = {}, FRI = nil> = {
	grade: ((form: Form<N, QL, FRI>, responce: FormResponce<FRI>) -> (boolean, number, { [QuestionResponce]: boolean })) &
		((form: Form<N, QL, FRI>, responce: buffer) -> (boolean, number, { [QuestionId]: boolean })),
	get_question: (<QN>(form: Form<N, QL, FRI>, name: QN & keyof<QL>) -> index<QL, QN> & RegisteredQuestionInfo) &
		--TODO: replace the any return with a type function when interger literals are added
		(<QI>(form: Form<N, QL, FRI>, id: QI) -> any),
	get_serializer: (form: Form<N, QL, FRI>) -> FormSerializer<Form<N, QL, FRI>>,
	to_buffer: (form: Form<N, QL, FRI>, buffer_info: FormBufferInfo) -> buffer,
	__index: FormPrototype<N, QL, FRI>,
}

export type Form<N = string, QL = {}, FRI = nil> = setmetatable<({
	read max_responce_buffer_size: number,
	read can_fully_autograde: boolean,
	read min_points: number,
} & (
	-- TODO: use a type function for converting QL to an array when numeric literals are added
	| BaseFormInfo<boolean, false?, { MixedQuestion & RegisteredQuestionInfo }, N>
	| BaseFormInfo<boolean, false?, { QuizQuestion & RegisteredQuestionInfo }, N>
)), FormPrototype<N, QL, FRI>>

-- qquestion is quizquestion its just quiz makes the variable too long
local ERR_QQUESTION_FIELD_UNDEFINED = `[FORM]: question '%*' is a quiz '%*' question without the '%*' field defined in the answer table`
local POINTS_PER_QUESTION = 100
local DEFAULT_BONUS_POINTS = 50
local FORMAT = string.format

local function WRITE_SHORT_STRING(b: buffer, offset: number, s: string): number
	buffer.writeu8(b, offset, #s)
	offset += 1
	buffer.writestring(b, offset, s)
	return offset + #s
end

local function WRITE_LONG_STRING(b: buffer, offset: number, s: string): number
	buffer.writeu16(b, offset, #s)
	offset += 2
	buffer.writestring(b, offset, s)
	return offset + #s
end

local function WRITE_BOOLEAN(b: buffer, offset: number, v: boolean)
	buffer.writeu8(b, offset, if v == false then 0 else 1)
end

-- this guy doesnt inline so native it will be 
@native
local function WRITE_CHOICES(
	b: buffer, offset: number, choices: { string },
	answer_ids: { [number]: string }
): number
	buffer.writeu8(b, offset, #choices - 1)
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

local function IF_NOT_INFO_THEN<I, V>(info: I, v: V): V | false
	return not (info :: any) and (v :: any)
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

function form_serializer.finish(serializer)

end

local form_prototype = {} :: getmetatable<Form>

function form_prototype.get_question(form, name_or_id)
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

@native
local function grade_buffer(
	form: Form, responce: buffer
): (boolean, number, { [QuestionId]: boolean })
	
end

local function grade_table(
	form: Form, responce: FormResponce
): (boolean, number, { [string]: boolean })
	
end

function form_prototype.grade(form, responce)
	if type(responce) == "buffer" then
		return grade_buffer(form, responce)
	else
		return grade_table(form, responce)
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
function form_prototype.to_buffer(form: Form, info: FormBufferInfo?)
	local include_questions = (info and info.include_questions) or IF_NOT_INFO_THEN(info, true)
	local include_answers = (info and include_questions and info.include_answers) or IF_NOT_INFO_THEN(info, true)
	local include_info = (info and info.include_info) or IF_NOT_INFO_THEN(info, true)
	local size = if include_info then #form.name + 7 else 0
	local questions = form.questions
	--[[
		the starting offset is the same as the base size
		so offset is declared here to save time
	]]
	local offset = size

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
		WRITE_BOOLEAN(b, 0, form.is_quiz)
		WRITE_BOOLEAN(b, 1, form.can_fully_autograde)
		WRITE_BOOLEAN(b, 2, form.award_partially_correct)
		buffer.writeu16(b, 3, form.min_points)
		buffer.writeu8(b, 5, #questions)
		WRITE_SHORT_STRING(b, 6, form.name)
	end

	if include_questions then
		for _, question in questions do
			local answer = include_answers and question.answer
			local question_type = question.type

			buffer.writeu8(b, offset, question.id)
			offset += 1
			buffer.writeu8(b, offset, TYPE_TO_NUM(question_type))
			offset += 1
			WRITE_BOOLEAN(b, offset, answer ~= nil)
			offset += 1
			WRITE_BOOLEAN(b, offset, question.required)
			offset += 1
			buffer.writeu8(b, offset, question.bonus)
			offset = WRITE_SHORT_STRING(b, offset + 1, question.name)

			if question_type == "Scale" then
				buffer.writeu8(b, offset, question.from)
				offset += 1
				buffer.writeu8(b, offset, question.to)
				offset += 1

				if answer then
					buffer.writeu8(b, offset, answer.from)
					offset += 1
					buffer.writeu8(b, offset, answer.to)
					offset += 1
				end
			elseif question_type == "Text" then
				--[[
					min/max len wont be nil because when registering if the form info doesnt have them defined
					they get defined to the default min maxes
				]]
				buffer.writeu16(b, offset, question.min_len)
				offset += 2
				buffer.writeu16(b, offset, question.max_len)
				offset += 2

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

function form_prototype.get_serializer(form)
	return setmetatable({
		buffer = buffer.create(form.max_responce_buffer_size),
		info_len = 0,
		offset = 256,
		form = form,
	}, form_serializer)
end

local form = {}

--TODO: add overload for registering from a buffer
function form.register<N, QL, FRI>(info: FormInfo<N, QL>): Form<N, QL, FRI>
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
	info.serializer = serializer

	return table.freeze(setmetatable(info, form_prototype))
end

@native
function form.get_responce_buffer_info(responce_buffer: buffer): buffer
	
end

function form.serializer<F>(form: F): FormSerializer<F>
	
end

do

	form_serializer.__index = form_serializer
	form_prototype.__index = form_prototype :: any
	table.freeze(form_serializer)
	table.freeze(form_prototype)

end

return table.freeze(form)
