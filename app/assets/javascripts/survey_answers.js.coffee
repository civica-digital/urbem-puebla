$(document).on 'change', '.js-answer-selection', ->
  answerType = $(this).val()
  $(this).parent().closest(".js-question").find(".js-answer-wrapper").addClass("hidden")
  $(this).parent().closest(".js-question").find(".js-" + answerType).removeClass("hidden")