require 'spec_helper'

feature 'User can answer service surveys' do
  let(:user) { create(:user) }

  background do
    sign_in_user user
  end

  scenario 'with binary questions' do
    service = create :service, name: "Actas de nacimiento"
    first_question = create :question, :binary, text: "¿Te pareció bueno el servicio?", value: 50
    second_question = create :question, :binary, text: "¿Se te brindó atención rápido?", value: 50
    survey = create(:service_survey, services: [service], title: "Encuesta acta de nacimiento", phase: "start", open: true, questions: [first_question, second_question])

    visit service_surveys_path
    click_link "Iniciar evaluación"

    within all(".pt-page").first do
      expect(current_path).to eq new_answer_path
      expect(page).to have_content "1 Pregunta restante"
      expect(page).to have_content "¿Te pareció bueno el servicio?"
      expect(page).not_to have_content "¿Se te brindó atención rápido?"

      choose "Sí"
      click_link "Siguiente pregunta"
    end

    within all(".pt-page")[1] do
      expect(page).to have_content "0 Preguntas restantes"
      expect(page).not_to have_content "¿Te pareció bueno el servicio?"
      expect(page).to have_content "¿Se te brindó atención rápido?"

      choose "No"
      click_button "Terminar evaluación"
    end

    expect(current_path).to eq service_survey_path(survey)
    expect(page).to have_content "Gracias por evaluar el servicio."
    expect_survey_confirmation_email_sent_to user.email
  end

  scenario 'and answer another survey' do
    service = create :service, name: "Actas de nacimiento"
    question = create :question, :binary, text: "¿Te pareció bueno el servicio?", value: 100
    other_question = create :question, :binary, text: "¿Te trataron bien?", value: 100

    survey = create(:service_survey, services: [service], title: "Encuesta acta de nacimiento", phase: "start", open: true, questions: [question])
    other_survey = create(:service_survey, services: [service], title: "Encuesta acta de nacimiento 2", phase: "middle", open: true, questions: [other_question])

    visit new_answer_path(service_survey_id: survey.id)

    within all(".pt-page").first do
      expect(page).to have_button "Terminar evaluación"
      expect(page).to have_button "Iniciar siguiente evaluación"
      expect(page).to have_content "¿Te pareció bueno el servicio?"
      choose "Sí"
      click_button "Iniciar siguiente evaluación"
    end

    expect_survey_confirmation_email_sent_to user.email
    expect(current_path).to eq new_answer_path
    expect(page).to have_content "Gracias por evaluar el servicio."
    expect(page).to have_content "¿Te trataron bien?"
  end

  scenario 'but only once' do
    service = create :service, name: "Actas de nacimiento"
    survey = create(:survey_with_binary_question, services: [service], title: "Encuesta acta de nacimiento", phase: "start", open: true)
    answer = create :survey_answer, user_id: user.id, question_id: survey.questions.first.id

    visit service_surveys_path
    expect(page).to have_content "Encuesta acta de nacimiento"
    expect(page).to have_content "Evaluada"
    expect(page).not_to have_link "Iniciar evaluación"
  end

  def expect_survey_confirmation_email_sent_to(email)
    last_email = ActionMailer::Base.deliveries.last || :no_email_sent
    expect(last_email.to).to include(email)
    expect(last_email.subject).to include "Gracias por tu evaluación"
  end
end