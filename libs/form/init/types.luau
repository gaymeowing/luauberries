
-- types
-- stores all the types for form

-- Enums 

export type QuestionType = "MultipleChoice" | "Text" | "Scale" | "Checkboxes"

-- Question Bases

export type BaseQuestionBase<TYPE, A, MAXL, MINL, F, T> = {
	required: boolean?,
	max_len: MAXL,
	min_len: MINL,
	answer: A,
	type: TYPE,
	from: F,
	to: T,
}

export type QuestionBase<TYPE, A, MAXL, MINL, F, T> = BaseQuestionBase<TYPE, A, MAXL, MINL, F, T>

export type AnswersOnlyQuestionBase<TYPE, A> = QuestionBase<TYPE, A, nil, nil, nil, nil>

-- Questions

export type TextQuizQuestion = QuestionBase<"Text", string, number?, number?, nil, nil>

export type TextQuestion = QuestionBase<"Text", string, number?, number?, nil, nil>

export type MultipleChoiceQuestion = AnswersOnlyQuestionBase<"MultipleChoice", { string }>

export type MultipleChoiceQuizQuestion = AnswersOnlyQuestionBase<"MultipleChoice", {
	incorrect: { string },
	correct: { string }
}>

export type CheckboxesQuestion = AnswersOnlyQuestionBase<"Checkboxes", { string }>

export type CheckboxesQuizQuestion = AnswersOnlyQuestionBase<"Checkboxes", {
	incorrect: { string },
	correct: { string },
}>

export type ScaleQuestion = QuestionBase<"Scale", nil, nil, nil, number, number>

export type ScaleQuizQuestion = QuestionBase<"Scale", number, nil, nil, number, number>

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

type BaseFormInfo<IQ, Q, N> = {
	default_points_per_question: number?,
	questions: { [string]: Q },
	percent_to_pass: number?,
	is_quiz: IQ,
	name: N,
}

export type FormInfo<N = string> =
	| BaseFormInfo<false?, MixedQuestion, N>
	| BaseFormInfo<true, QuizQuestion, N>

export type RegisteredFormInfo<N = string> = FormInfo<N> & {
	max_points: number,
	min_points: number,
}
	
export type FormResponce<T> = {
	question_responces: { QuestionResponce },
	form_name: string,
	info: T,
}

return nil
