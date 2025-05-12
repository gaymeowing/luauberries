
-- form
-- module for validating forms 

export type QuestionType = "MultipleChoice" | "Text" | "Scale" | "Checkboxes"

-- Question Bases

type BaseQuestionBase<TYPE, A, MAXL, MINL, F, T, B, R> = {
	max_len: MAXL,
	min_len: MINL,
    required: R,
	type: TYPE,
    answer: A,
    bonus: B,
	from: F,
	to: T,
}

export type QuizQuestionBase<TYPE, A, MAXL, MINL, F, T> = 
    | BaseQuestionBase<TYPE, A, MAXL, MINL, F, T, number | true, false>
    | BaseQuestionBase<TYPE, A, MAXL, MINL, F, T, nil, true>

export type QuestionBase<TYPE, A, MAXL, MINL, F, T> = BaseQuestionBase<TYPE, A, MAXL, MINL, F, T, nil, false?>

export type AnswersOnlyQuizQuestionBase<TYPE, A> = QuizQuestionBase<TYPE, A, nil, nil, nil, nil>

export type AnswersOnlyQuestionBase<TYPE, A> = QuestionBase<TYPE, A, nil, nil, nil, nil>

-- Questions

export type TextQuizQuestion = QuizQuestionBase<"Text", string, number?, number?, nil, nil>

export type TextQuestion = QuestionBase<"Text", string, number?, number?, nil, nil>

export type MultipleChoiceQuestion = AnswersOnlyQuestionBase<"MultipleChoice", { string }>

export type MultipleChoiceQuizQuestion = AnswersOnlyQuizQuestionBase<"MultipleChoice", {
	incorrect: { string },
	correct: { string }
}>

export type CheckboxesQuestion = AnswersOnlyQuestionBase<"Checkboxes", { string }>

export type CheckboxesQuizQuestion = AnswersOnlyQuizQuestionBase<"Checkboxes", {
	incorrect: { string },
	correct: { string },
}>

export type ScaleQuizQuestion = QuizQuestionBase<"Scale", number, nil, nil, number, number>

export type ScaleQuestion = QuestionBase<"Scale", nil, nil, nil, number, number>

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

type FormSerializerPrototype<N = string, QL = {}, FRI = nil> = {
    --TODO: replace the any for the answer param with a type function
    record_question: <QN>(serializer: FormSerializer<N, QL, FRI>, name: QN, answer: any) -> (),
    write_info: (serializer: FormSerializer<N, QL, FRI>, info: buffer) -> (),
    finish: (serializer: FormSerializer<N, QL, FRI>) -> buffer,
    __index: FormSerializerPrototype<N, QL, FRI>,
}

type FormSerializer<N = string, QL = {}, FRI = nil> = setmetatable<{
    form: Form<N, QL, FRI>
}, FormSerializerPrototype<N, QL, FRI>>

type FormPrototype<N = string, QL = {}, FRI = nil> = {
    grade: ((form: Form<N, QL, FRI>, responce: FormResponce<FRI>) -> (boolean, number, { [QuestionResponce]: boolean })) &
        ((form: Form<N, QL, FRI>, responce: buffer) -> (boolean, number, { [QuestionId]: boolean })),
    get_question: <QN>(form: Form<N, QL, FRI>, name: QN & keyof<QL>) -> index<QL, QN> & RegisteredQuestionInfo,
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

local FORMS = {} :: { [string]: Form }
local POINTS_PER_QUESTION = 100
local DEFAULT_BONUS_POINTS = 50

local function FREEZE_IF_NOT_FROZEN<T>(t: T & {}): T
    if not table.isfrozen(t) then
        table.freeze(t)
    end
    return t
end

local function GET_PERCENT(n: number, percent: number)
	return (percent * n) / 100
end

-- using the prototype types no workey :(
local serializer = {} :: getmetatable<FormSerializer>

function serializer.record_question(serializer, name, answer)
    
end

function serializer.write_info(serializer, info)
    
end

function serializer.finish(serializer)
    
end

local registered_form = {} :: getmetatable<Form>

function registered_form.get_question(form, name)
    for _, question in form.questions do
        if question.name == name then
            return question
        end
    end

    return nil :: any
end

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

local form = {}

function form.register<N, QL, FRI>(info: FormInfo<N, QL>): Form<N, QL, FRI>
    local name = info.name

    if FORMS[name] then
        error(`[FORM]: cannot have more than one quiz registered with the name '{name}'`)
    end

    local default_bonus_points = info.default_bonus_points or DEFAULT_BONUS_POINTS
    local percent_to_pass = info.percent_to_pass or 70
    -- this array is too complex to type here so its just becoming any
    local questions_array = {} :: { any }
    local can_fully_autograde = true
    local required_points = 0
    local next_id = 0

    for name, question: MixedQuestion in info.questions do
        local answer = question.answer

        if type(answer) == "table" then
            local incorrect = answer.incorrect
            local correct = answer.correct

            if incorrect and not correct then
                error(`[FORM]: question '{name}' is a quiz question without the 'correct' field defined in the answer table`)
            elseif correct and not incorrect then
                error(`[FORM]: question '{name}' is a quiz question without the 'incorrect' field defined in the answer table`)
            elseif correct and incorrect then
                FREEZE_IF_NOT_FROZEN(incorrect)
                FREEZE_IF_NOT_FROZEN(correct)
            end

            FREEZE_IF_NOT_FROZEN(answer)
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
        next_id += 1
    end

    if info.award_partially_correct == nil then
        info.award_partially_correct = true
    end

    info.min_points = GET_PERCENT(required_points, info.percent_to_pass or 70)
    info.can_fully_autograde = can_fully_autograde
    info.questions = questions_array
    FORMS[name] = info
    return table.freeze(setmetatable(info, registered_form))
end

function form.get_responce_buffer_info(responce_buffer: buffer): buffer
    
end

do

    registered_form.__index = registered_form
    serializer.__index = serializer
    table.freeze(registered_form)
    table.freeze(serializer)

end

return table.freeze(form)
