require 'spec_helper'

feature 'Admin can ignore survey answers' do
  let(:admin) { create(:admin) }

  scenario 'from service evaluations' do
    user = create :user
    other_user = create :user
    ignored_user = create :user
    service = create :service, name: "Actas de nacimiento", cis: ["1"], admins: [create(:admin, :public_servant)]
    survey = create(:survey_with_multiple_questions, services: [service], title: "Encuesta acta de nacimiento", phase: "start", open: true)

    given_survey_has_answers_for(survey, user: user, binary: "Sí", rating: "Regular", list: "Custom", open: "Mis sugerencias", score: 1.0 )
    given_survey_has_answers_for(survey, user: other_user, binary: "Sí", rating: "Regular", list: "Custom", open: "Mis sugerencias", score: 1.0 )
    given_survey_has_answers_for(survey, user: ignored_user, binary: "No", rating: "Muy Satisfecho", list: "Una respuesta", open: "Una respuesta tonta", score: 0.0 )
    given_survey_report_exists_for survey

    sign_in_admin admin
    visit service_evaluation_path(service)

    expect(page).to have_content user.name
    expect(page).to have_content other_user.name
    expect(page).to have_content ignored_user.name

    click_ignore_answers_for ignored_user
    expect(page).to have_content "Las respuestas del usuario serán ignoradas en la generación de nuevos reportes."
    expect(page).to have_content "Ignoradas"

    click_enable_answers_for ignored_user
    expect(page).not_to have_content "Ignoradas"
    expect(page).to have_content "Las respuestas del usuario han sido habilitadas en la generación de nuevos reportes."
  end

  def click_ignore_answers_for(user)
    find("#ignore_user_answers_#{user.id}").click
  end

  def click_enable_answers_for(user)
    find("#enable_user_answers_#{user.id}").click
  end

  def given_survey_has_answers_for(survey, answers_data)
    survey.questions.each do |question|
      if [:binary, :rating].include? question.answer_type.to_sym
        SurveyAnswer.create!(text: answers_data[question.answer_type.to_sym], question_id: question.id, score: answers_data[:score] * question.value, user_id: answers_data[:user].id)
      else
        SurveyAnswer.create!(text: answers_data[question.answer_type.to_sym], question_id: question.id, score: nil, user_id: answers_data[:user].id)
      end
    end
  end

  def given_survey_report_exists_for(survey)
    survey.services.each do |a|
      ServiceSurveyReport.create!(service_survey_id: survey.id, service_id: a.id)
    end
  end
end