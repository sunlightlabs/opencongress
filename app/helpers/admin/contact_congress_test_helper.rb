module Admin::ContactCongressTestHelper
  SUCCESS_PATTERN = /\ASENT\Z/
  FAILURE_PATTERN = /SENT_AS_FAX|ERROR/
  UNKNOWN_PATTERN = /WARNING|START/

  def status_image_for_test(test)
    if (test.status =~ FAILURE_PATTERN).present?
      img = 'fail.png'
    elsif (test.status =~ SUCCESS_PATTERN).present?
      img = 'success.png'
    elsif (test.status =~ UNKNOWN_PATTERN).present?
      img = 'unknown.png'
    else
      img = 'not_tried.png'
    end

    img || nil
  end
end