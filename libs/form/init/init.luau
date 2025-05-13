
--[[
	form
	module for validating forms
]]

local random = require("../random")
local weak = require("../weak")

export type QuestionType = "MultipleChoice" | "Text" | "Scale" | "Checkboxes"

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

export type QuizQuestionBase<TYPE, A, C, MAXL, MINL, F, T> = 
	| BaseQuestionBase<TYPE, A, C, MAXL, MINL, F, T, number | true, false>
	| BaseQuestionBase<TYPE, A, C, MAXL, MINL, F, T, nil, true>

export type QuestionBase<TYPE, A, C, MAXL, MINL, F, T> = BaseQuestionBase<TYPE, A, C, MAXL, MINL, F, T, nil, false?>

export type AnswersOnlyQuizQuestionBase<TYPE, A> = QuizQuestionBase<TYPE, A, nil, nil, nil, nil, nil>

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

export type QuestionResponceBase<T = QuestionType, R = string> = {
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
	form responce buffer spec:
	1 bytes for info len
	variable bytes for info
	variable bytes for questions

	for each question:
	1 byte question id

	checkboxes:
	1 byte for choices len
	variable bytes for the ids for each choice

	multiple choice:
	1 byte for choice

	scale:
	1 byte for position on scale selected

	text:
	8 bytes float for len
	variable bytes for string
]]
type SerializerInfo = {
	buffers: { buffer },
	b: buffer,
}

type FormSerializerPrototype<N = string, QL = {}, FRI = nil> = {
	--TODO: replace the any for the answer param with a type function
	record_question: (<QN>(serializer: FormSerializer<N, QL, FRI>, name: QN, answer: any) -> ()) &
		((<QI>(serializer: FormSerializer<N, QL, FRI>, id: QI, answer: any) -> ())),
	write_info: (serializer: FormSerializer<N, QL, FRI>, info: buffer) -> (),
	finish: (serializer: FormSerializer<N, QL, FRI>) -> buffer,
	__index: FormSerializerPrototype<N, QL, FRI>,
}

type FormSerializer<N = string, QL = {}, FRI = nil> = setmetatable<{
	form: Form<N, QL, FRI>
}, FormSerializerPrototype<N, QL, FRI>>

type BaseFormBufferInfo<SQ, IA, IQ, SC, R> = {
	random_for_shuffling: R,
	shuffle_questions: SQ,
	include_questions: IQ,
	include_answers: IA,
}

type FormBufferInfo = 
	| BaseFormBufferInfo<true, boolean?, true?, random.Random>
	| BaseFormBufferInfo<false?, nil>

type FormPrototype<N = string, QL = {}, FRI = nil> = {
	grade: ((form: Form<N, QL, FRI>, responce: FormResponce<FRI>) -> (boolean, number, { [QuestionResponce]: boolean })) &
		((form: Form<N, QL, FRI>, responce: buffer) -> (boolean, number, { [QuestionId]: boolean })),
	get_question: <QN>(form: Form<N, QL, FRI>, name: QN & keyof<QL>) -> index<QL, QN> & RegisteredQuestionInfo,
	to_buffer: (form: Form<N, QL, FRI>, buffer_info: FormBufferInfo) -> buffer,
	__index: FormPrototype<N, QL, FRI>,
}

export type Form<N = string, QL = {}, FRI = nil> = setmetatable<({
	read serializer: FormSerializer<N, QL, FRI>,
	read can_fully_autograde: boolean,
	read min_points: number,
} & (
	-- TODO: use a type function for converting QL to an array when numeric literals are added
	| BaseFormInfo<boolean, false?, { MixedQuestion & RegisteredQuestionInfo }, N>
	| BaseFormInfo<boolean, false?, { QuizQuestion & RegisteredQuestionInfo }, N>
)), FormPrototype<N, QL, FRI>>

-- qquestion is quizquestion its just quiz makes the variable too long
local ERR_QQUESTION_FIELD_UNDEFINED = `[FORM]: question '%*' is a quiz '%*' question without the '%*' field defined in the answer table`
local SERIALIZER_INFO = weak.create("k") :: { [FormSerializer]: SerializerInfo }
local POINTS_PER_QUESTION = 100
local DEFAULT_BONUS_POINTS = 50
local FORMAT = string.format

--TODO: replace return w type function
local function GET_QUESTION(form: Form, name_or_id: string | QuestionId): MixedQuestion
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

local function WRITE_SHORT_STRING(b: buffer, offset: number, s: string): number
	buffer.writeu8(b, offset, #s)
	buffer.writestring(b, offset + 1, s)
	return offset + #s + 1
end

local function WRITE_BOOLEAN(b: buffer, offset: number, v: boolean)
	buffer.writeu8(b, offset, if v == false then 0 else 1)
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
local serializer = {} :: getmetatable<FormSerializer>

function serializer.record_question(serializer, name_or_id, answer)
	local serializer_info = SERIALIZER_INFO[serializer]
	local question = GET_QUESTION(serializer.form, name_or_id)

end

function serializer.write_info(serializer, info)
	local serializer_info = SERIALIZER_INFO[serializer]
	local len = buffer.len(info)

	if len > 255 then
		error("[FORM]: info buffer len cannot be greater than 255", 2)
	end
	
	local new_info = buffer.create(len + 1)
	buffer.writeu8(new_info, 0, len)
	buffer.copy(new_info, 1, info)
	serializer_info.buffers[1] = new_info
end

function serializer.finish(serializer)
	local serializer_info = SERIALIZER_INFO[serializer]

end

local registered_form = {
	get_question = GET_QUESTION
} :: getmetatable<Form>

@native
local function grade_buffer(
	form: Form, responce: buffer
): (boolean, number, { [QuestionId]: boolean })
	
end

local function grade_table(
	form: Form, responce: FormResponce
): (boolean, number, { [string]: boolean })
	
end

function registered_form.grade(form, responce)
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

	choice:
		1 byte id
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

		multiple choice:
			if is_quiz then
				1 byte correct len
				1 byte incorrect len
				variable bytes for correct choices
				variable bytes for incorrect choices
			else
				1 byte choices len
				variable bytes for choices

		checkboxes:
			if is_quiz then
				1 byte correct len
				1 byte incorrect len
				variable bytes for correct choices
				variable bytes for incorrect choices
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
			4 bytes min len
			4 bytes max len

			if is_quiz then
				4 bytes answer len
				0..4_294_967_295 bytes for answer
]]
function registered_form.to_buffer(form: Form, info: FormBufferInfo?)
	local include_answers = (info and info.include_answers) or true
	local questions = form.questions
	local name = form.name
	local size = #name + 7
	--[[
		the starting offset is the same as the base size
		so offset is declared here to save time
	]]
	local offset = size

	if info and info.shuffle_questions then
		(info.shuffle_random or random.create()):shuffle(questions)
	end

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
			size += 8

			if answer then
				size += #answer + 4
			end
		else
			local answer_ids = question.answer_ids
			size += (#answer_ids * 2) + 1

			for _, choice in answer_ids do
				size += #choice
			end

			if answer then
				size += 1
			end
		end
	end

	local b = buffer.create(size)
	
	WRITE_BOOLEAN(b, 0, form.is_quiz)
	WRITE_BOOLEAN(b, 1, form.can_fully_autograde)
	WRITE_BOOLEAN(b, 2, form.award_partially_correct)
	buffer.writeu16(b, 3, form.min_points)
	buffer.writeu8(b, 5, #questions)
	WRITE_SHORT_STRING(b, 6, name)

	for _, question in questions do
		local answer = include_answers and question.answer
		local question_type = question.type

		buffer.writeu8(b, offset, question.id)
		offset += 1
		buffer.writeu8(b, offset, TYPE_TO_NUM(question_type))
		offset += 1
		WRITE_BOOLEAN(b, offset, answer ~= false)
		offset += 1
		WRITE_BOOLEAN(b, offset, question.required)
		offset += 1
		buffer.writeu8(b, offset, question.bonus or 0)
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
			
		else

		end
	end

	return b
end

local form = {}

--TODO: add overload for registering from a buffer
function form.register<N, QL, FRI>(info: FormInfo<N, QL>): Form<N, QL, FRI>
	local default_bonus_points = info.default_bonus_points or DEFAULT_BONUS_POINTS
	local percent_to_pass = info.percent_to_pass or 70
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

	local serializer = table.freeze(setmetatable({ form = info }, serializer))
	SERIALIZER_INFO[serializer] = {
		buffers = {}
	}

	info.min_points = (required_points * (info.percent_to_pass or 70)) // 100
	info.can_fully_autograde = can_fully_autograde
	info.questions = questions_array
	info.serializer = serializer

	return table.freeze(setmetatable(info, registered_form))
end

@native
function form.get_responce_buffer_info(responce_buffer: buffer): buffer
	
end

do

	registered_form.__index = registered_form
	serializer.__index = serializer
	table.freeze(registered_form)
	table.freeze(serializer)

end

return table.freeze(form)
