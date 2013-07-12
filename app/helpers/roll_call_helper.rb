module RollCallHelper
  def person_type
    case @roll_call.chamber
      when 'House' then 'Representative'
      when 'Senate' then 'Senator'
    end
  end
  
  def vote_name(vote)
    vote_names = {
      '+' => 'Aye',
      'aye' => 'Aye',
      'yea' => 'Aye',
      '-' => 'Nay',
      'no' => 'Nay',
      'nay' => 'Nay',
      'p' => 'Present',
      'present' => 'Present',
      '0' => 'Not Voting',
      'not voting' => 'Not Voting'
    }
    vote_names.fetch(vote.downcase, vote)
  end

  def singular_vote_css_class(vote)
    classes = {
      '+' => 'aye',
      'aye' => 'aye',
      'yea' => 'aye',
      '-' => 'nay',
      'no' => 'nay',
      'nay' => 'nay',
      'p' => 'abs',
      'present' => 'abs',
      '0' => 'abs',
      'not voting' => 'abs'
    }
    classes[vote.downcase]
  end

  def plural_vote_css_class(vote)
    classes = {
      '+' => 'ayes',
      'aye' => 'ayes',
      'yea' => 'ayes',
      '-' => 'nays',
      'no' => 'nays',
      'nay' => 'nays',
      'p' => 'abs',
      'present' => 'abs',
      '0' => 'abs',
      'not voting' => 'abs'
    }
    classes[vote.downcase]
  end

  def count_for_vote_and_party (vote, party)
    @party_vote_counts.fetch([vote, party], 0)
  end

  def count_for_affirmative_votes_by_party (party)
    count_for_vote_and_party('Aye', party) + count_for_vote_and_party('Yea', party) + count_for_vote_and_party('+', party)
  end

  def count_for_negative_votes_by_party (party)
    count_for_vote_and_party('No', party) + count_for_vote_and_party('Nay', party) + count_for_vote_and_party('-', party)
  end

  def count_for_present_votes_by_party (party)
    count_for_vote_and_party('Present', party) + count_for_vote_and_party('P', party)
  end

  def count_for_non_votes_by_party (party)
    count_for_vote_and_party('Not Voting', party) + count_for_vote_and_party('0', party)
  end

  def count_for_affirmative_votes 
    @vote_counts.fetch('Aye', 0) + @vote_counts.fetch('Yea', 0) + @vote_counts.fetch('+', 0)
  end

  def count_for_negative_votes
    @vote_counts.fetch('No', 0) + @vote_counts.fetch('Nay', 0) + @vote_counts.fetch('-', 0)
  end

  def count_for_present_votes
    @vote_counts.fetch('Present', 0) + @vote_counts.fetch('P', 0)
  end

  def count_for_non_votes
    @vote_counts.fetch('Not Voting', 0) + @vote_counts.fetch('0', 0)

  end

  # Motivating example for this is using "Not Voting" => "not_voting" for 
  # the Flash <-> JavaScript coordination for chart on_click events.
  def vote_name_suitable_for_id (vote_type)
    vote_type.gsub(/ /, '_').downcase
  end

  def chart_html_for_vote_type (vote_type, width=400, height=220, params={})
    params['breakdown_type'] = vote_type
    ofc2(width, height, "roll_call/partyvote_piechart_data/#{@roll_call.id}?" + params.to_param)
  end

  def humane_fraction (fr)
    case fr
    when '1/2' then 'one half'
    when '2/3' then 'two thirds'
    when '3/5' then 'three fifths'
    else fr
    end
  end

  def numeric_percentage(roll_call)
    case roll_call.required
    when '1/2' then "(50%)"
    when '2/3' then "(66%)"
    when '3/5' then "(60%)"
    end  
  end
end
