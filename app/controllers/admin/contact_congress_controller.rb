class Admin::ContactCongressController < Admin::IndexController
  before_filter :admin_login_required

  def index
    @page_title = 'Contact Congress Configuration'
    @people = Person.all_sitting
  end

  def overview
    @page_title = 'Last Delivery Attempt'
    @passed = ContactCongressTest.recently_passed
    @failed = ContactCongressTest.recently_failed
    @captcha_required = ContactCongressTest.recently_captcha_required
    @unknown = ContactCongressTest.recently_unknown
  end

  def letters
    @page_title = 'Contact Congress Letters'
    @letters = ContactCongressLetter.order('created_at DESC').all.paginate(:per_page => 50, :page => params[:page])
  end

  def stats
    @page_title = 'Contact Congress Stats'
    @people = Person.all_sitting
  end

  def result
    @test = ContactCongressTest.find(params[:id])
    form_url = Person.find_by_bioguideid(@test.bioguideid).formageddon_contact_steps.first.command.sub('visit::', '')
    uri = Addressable::URI.parse(form_url)
    @baseurl = "#{uri.scheme}://#{uri.host}"
    render "result", :layout => false
  end
end
