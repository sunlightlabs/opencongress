module Admin::ContactCongressLettersHelper
  SUCCESS_PATTERN = /SENT/
  FAILURE_PATTERN = /SENT_AS_FAX|ERROR/
  UNKNOWN_PATTERN = /WARNING|START|CAPTCHA_REQUIRED/

  def status_image_for(person)
    last_status = person.formageddon_threads.first.formageddon_letters.first.status rescue nil
    if (last_status =~ FAILURE_PATTERN).present?
      img = 'fail.png'
    elsif (last_status =~ SUCCESS_PATTERN).present?
      img = 'success.png'
    elsif (last_status =~ UNKNOWN_PATTERN).present?
      img = 'unknown.png'
    else
      img = 'not_tried.png'
    end

    img || nil
  end

  def status_image_path(filename)
    "#{Rails.root}/public/#{status_image_url(filename)}"
  end

  def status_image_url(filename)
    "/images/contact-congress/#{filename}"
  end

  def success_percentage(person)
    @@to_delete ||= AbandonedThreadsJob.to_destroy(:since => 2.months.ago, :remove => [:orphaned, :inactive])
    total_cnt = person.formageddon_threads.includes(:formageddon_letters).where("formageddon_threads.created_at >= ? and formageddon_threads.id not in(?)", person.formageddon_contact_steps.last.updated_at, @@to_delete).size rescue 0
    return '?' unless total_cnt > 0
    success_cnt = person.formageddon_threads.includes(:formageddon_letters).where("formageddon_threads.created_at >= ? and formageddon_letters.status = 'SENT'", person.formageddon_contact_steps.last.updated_at).size rescue 0
    number_to_percentage(success_cnt.to_f / total_cnt.to_f * 100)
  end

end