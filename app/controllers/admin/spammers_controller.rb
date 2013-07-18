class Admin::SpammersController < Admin::IndexController
  before_filter :admin_login_required

  def mypn
    @users = User.mypn_spammers.paginate(:page => params[:page], :per_page => 100)
  end

  def mypn_bulk_update
    @items = NotebookItem.where("id IN(?)", params[:items])
    if params[:disposition].to_sym == :ham
      @items.each{|item| item.uncensor! :ham }
    else
      @items.each{|item| item.censor! :spam }
    end
    redirect_to :back
  end

  def mark_mypn_post_spam
    NotebookItem.find(params[:id]).censor! :spam rescue nil
    redirect_to :back
  end

  def mark_mypn_post_ham
    NotebookItem.find(params[:id]).uncensor! :ham rescue nil
    redirect_to :back
  end

  def mark_all_mypn_posts_spam
    @user = User.find_by_login(params[:id])
    @user.political_notebook.notebook_items.where(:spam => false).each{|item| item.censor! :spam }
    redirect_to :back
  end

  def mark_all_mypn_posts_ham
  @user = User.find_by_login(params[:id])
    @user.political_notebook.notebook_items.where(:spam => true).each{|item| item.uncensor! :ham }
    redirect_to :back
  end
end