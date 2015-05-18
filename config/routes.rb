OpenCongress::Application.routes.draw do
  # API
  constraints :subdomain => 'api' do
    match '/' => redirect(Settings.base_url + 'api')
    match '/:action(/:id)', :controller => 'api', to: proc { [410, {}, ['']] }
  end

  # to redirect all atoms if we choose to go down that route
  # match '/*atom'  => redirect(Settings.base_url), constraints: { atom: %r{.*atom.*} } #,to: proc { [410, {}, ['']] }

  resources :mailing_list_items
  resources :watch_dogs

  resources :states do
    resources :districts
  end

  resources :groups do
    resources :group_invites
    resources :group_members
    resources :group_bill_positions

    resource :political_notebook do
      resources :notebook_items do
        collection do
          get :feed
        end
      end
      resources :notebook_links
      resources :notebook_videos
      resources :notebook_notes
      resources :notebook_files
    end
  end

  resources :simple_captcha, :only => :show

  scope 'email_congress', :controller => :email_congress do
    match 'postmark/inbound', :action => :message_to_members
    post 'discard/:confirmation_code', :action => :discard
    match 'complete_profile/:confirmation_code', :action => :complete_profile
    match 'confirmed/:confirmation_code', :action => :confirmed
    match 'confirm/:confirmation_code', :action => :confirm
    match 'confirm', :action => :confirm
  end

  # Allow downloading Web Service WSDL as a file with an extension
  # instead of a file named 'wsdl'
  # match ':controller/service.wsdl' => 'wsdl'

  # Handle bill routing. The action determines what information about the bill will
  # be displayed.
  match 'bill/:id/users_tracking' => 'friends#tracking_bill', :as => :users_tracking_bill
  match 'bill/:id/users_tracking/:state' => 'friends#tracking_bill', :state => /\w{2}/, :as => :users_tracking_bill_by_state

  scope 'bill', :controller => 'bill' do
    for action in %w{ all pending popular major hot readthebill compare compare_by_issues atom_top20 }
      match action, :action => action, :as => 'bill_' + action
    end

    match 'most/:type', :action => 'most_commentary', :as => :bill_most_commentary
    match 'most/viewed', :action => 'popular'
    match 'atom/most/viewed', :action => 'atom_top20'
    match 'atom/most/:type', :action => 'atom_top_commentary'
    match 'atom/list/:chamber', :action => 'atom_list'
    match 'type/:bill_type(/:page)', :action => 'list_bill_type'
    match 'text/status/:id', :action => 'status_text'
    match 'upcoming/:id', :action => 'upcoming'
    match 'bill_vote/:bill/:id', :action => 'bill_vote'

    scope ':id' do
      match 'blogs(/:page)', :action => 'blogs', :as => :blogs_bill
      match 'blogs/search(/:page)', :action => 'commentary_search', :commentary_type => 'blog'
      match 'news(/:page)', :action => 'news', :as => :news_bill
      match 'news/search(/:page)', :action => 'commentary_search', :commentary_type => 'news'
      match 'text', :action => 'text', :as => :bill_text
      match 'comments', :action => 'comments', :as => :bill_comments
      match 'show', :action => 'show', :as => :bill
      match ':action'
    end

    match ':id' => 'bill#show'

  end
  match 'bill' => redirect('/bill/all')

  scope 'people', :controller => 'people' do
    match 'senators', :action => 'people_list', :person_type => 'senators'
    match 'representatives', :action => 'people_list', :person_type => 'representatives'
    match ':person_type/most/:type', :action => 'most_commentary'
    match ':person_type/atom/most/:type', :action => 'atom_top_commentary'
    match 'atom/featured', :action => 'atom_featured'
    match 'wiki/:id', :action => 'wiki'
    match 'news/:id(/:page)', :action => 'news', :as => :news_person
    match 'blogs/:id(/:page)', :action => 'blogs', :as => :blogs_person
    match 'votes_with_party/:chamber/:party', :action => 'votes_with_party'
    match 'voting_history/:id/:page', :action => 'voting_history', :constraints => { :page => /\d+/ }
    match 'compare.:format', :action => 'compare'
    match 'show/:id', :action => 'show', :as => 'person'
    match 'bills/:id', :action => 'bills', :constraints => { :page => /^\d+/ }
  end

  match 'person/*path' => redirect("/people/%{path}")

  namespace :admin do
     resources :wiki_links, :pvs_category_mappings, :talking_points
     resources :articles do
       collection do
         get :list
         get :edit_blogroll
       end
       resources :article_images
     end

     match '/' => 'index#index', :as => 'admin'

     scope 'stats', :controller => 'stats' do
       match 'bills.:format', :action => 'bills'
       match 'partner_email.:format', :action => 'partner_email'
     end

     match 'contact_congress' => 'contact_congress#index'
     match 'contact_congress/letters' => 'contact_congress#letters'
  end
  match 'contact_congress/status/:id' => 'contact_congress_letters#last'

  match '/:controller(/:action(/:id))', :controller => /admin\/[^\/]+/

  match 'battle_royale' => 'battle_royale#index'
  match 'battle_royale/:action', :controller => 'battle_royale'

  match 'blog(/:tag)' => 'articles#list', :as => :blogs

  scope 'articles', :controller => 'articles' do
    match 'view/:id', :action => 'view', :as => :article
    match ':id/atom', :action => 'article_atom'
  end
  # Temporary redirect for DRM's announcement post
  match 'about/ppf-askthem' => redirect('/articles/view/2537-Big-News')

  match 'issues/most_viewed' => 'issue#most_viewed', :as => :most_viewed_issues
  match 'issues/all/(:id)' => 'issue#all', :as => :all_issues
  match 'issues' => 'issue#index', :as => :issues

  match 'roll_call', :controller => :roll_call, :action => :index
  match 'committee', :controller => :committee, :action => :index

  scope 'issues', :controller => 'issue' do
    match 'show/:id', :action => 'show', :as => :issue
    match ':action/:id'
  end


  #######TEMP REMOVE
  # scope :module => 'formageddon', :as => 'formageddon' do
  #   resources :formageddon_threads, :controller => 'threads', :path => '/formageddon/threads'
  #   resources :formageddon_contact_steps, :controller => 'contact_steps', :path => '/formageddon/contact_steps'
  # end
  #
  #
  #
  #
  #
  # # Install the default route as the lowest priority.
  # map.connect ':controller/:action/:id'


  scope 'contact_congress_letters', :controller => 'contact_congress_letters' do
    post ':id', :action => :update
  end

  resources :contact_congress_letters, :only => [:index, :show, :new, :update] do
    get 'create_from_formageddon', :on => :collection # create uses POST and we'll be redirecting to create
    get 'get_recipients', :on => :collection
    get 'delayed_send', :on => :collection
    get 'get_replies', :on => :collection
    get 'all_congress_letters', :on => :collection
  end

  scope :controller => 'account' do
    for action in %w{ login why logout signup welcome contact_congress determine_district }
      match action, :action => action
    end

    match 'register', :action => 'signup'
    match 'account/confirm/:login', :action => 'confirm'
  end

  scope :controller => 'comments' do
    match 'comments/all_comments/:object/:id', :action => 'all_comments'
    match 'comments/atom/:object/:id', :action => 'atom_comments'
  end

  # /users/:login
  scope 'users/:login' do
    get 'profile' => 'profile#show', :as => :user_profile
    get 'profile/edit' => 'profile#edit', :as => :edit_profile
    put 'profile' => 'profile#update', :as => :update_profile
    delete 'profile' => 'profile#destroy', :as => :destroy_profile
    delete 'profile/images' => 'profile#delete_images', :as => :delete_profile_images

    # /users/:login/profile
    scope 'profile' do

      resource :political_notebook do
        collection do
          post :update_privacy
          get :feed
        end
        resources :notebook_links do
          collection do
            get :faceform
          end
        end
        resources :notebook_videos
        resources :notebook_notes
        resources :notebook_files
      end

      # /users/:login/profile/friends/:action
      resources :friends
      scope 'friends', :controller => 'friends' do
        for action in %w{ import_contacts like_voters invite_contacts near_me invite invite_form add search }
          match action, :action => action, :as => 'friends_' + action
        end

        for action in %w{ confirm deny } do
          match action + '/:id', :action => action, :as => 'friends_add_' + action
        end
      end

      # /users/:login/profile/:action
      scope :controller => 'profile' do
        for action in %w{ actions downloads_index items_tracked tracked_bill_status tracked_votes watchdog edit_profile bills_supported tracked_rss user_actions_rss bills_opposed my_votes bills comments issues committees groups upload_pic
                          disconnect_facebook_account remove_bill_bookmark remove_person_bookmark tracked_commentary_news tracked_commentary_blogs } do
          match action, :action => action, :as => 'user_' + action
        end
        match ':person_type', :action => 'person'
      end

    end # scope 'profile'

    match 'feeds/:action(/:key)', :controller => 'user_feeds'

  end # scope 'users/:login'

  get 'users/:login' => redirect {|params, request| Rails.application.routes.url_helpers.user_profile_path(params[:login]) }

  match 'video/rss' => 'video#all', :format => 'atom'

  scope :controller => 'roll_call' do
    match 'roll_call/text/summary/:id', :action => 'summary_text'
    match 'vote/:year/:chamber/:number(/:state)', :action => 'by_number', :year => /\d{4}/, :chamber => /[hs]/, :number => /\d+/, :state => /\w{2}/, :as => :roll_call
  end

  scope :controller => 'committee' do
    match '/committee/by_chamber/:chamber', :action => 'by_chamber'
  end

  post '/subscribe.:format' => 'email_subscriptions#adhoc'

  match 'tools(/:action(/:id))', :controller => 'resources', :as => 'tools'

  match '/widgets' => 'widgets#index', :as => 'widgets'
  match '/widgets/deprecated' => 'widgets#deprecated', :as => 'deprecated_widgets'
  match '/widgets/bill' => 'widgets#bill', :as => 'bill_widget'
  match '/widgets/bills' => 'widgets#bills', :as => 'bills_widget'
  match '/widgets/people' => 'widgets#people', :as => 'people_widget'
  match '/widgets/group' => 'widgets#group', :as => 'group_widget'

  match 'api' => 'api#index'

  # Temporary routes for health care legislation
  match 'baucus_bill_health_care.html' => 'index#s1796_redirect'
  match 'presidents_health_care_proposal' => 'index#presidents_health_care_proposal'
  match 'senate_health_care_bill' => 'bill#text', :id => '111-h3590', :version => 'ocas'
  match 'house_reconciliation' => 'index#house_reconciliation'
  match 'pipa' => 'index#pipa'

  match '/donate' => redirect('http://sunlightfoundation.com/about/funding/')
  match '/about/privacy_policy' => redirect("/terms")
  match '/about/terms_of_service' => redirect("/terms")
  match 'terms' => 'about#terms'
  match 'howtouse' => 'about#howtouse'
  match '/userguide' => redirect("/howtouse")

  get '/banner-dismiss' => 'index#close_banner', as: 'close_banner'
  resources :contact, :only => [:index, :create]

  match ':controller(/:action(/:id))'
  #match '*path' => 'index#notfound' #unless Rails.application.config.consider_all_requests_local

  # root :to => 'index#index', :as => :home
  # Dev homepage
  root :to => 'index#index', :as => :home

end
