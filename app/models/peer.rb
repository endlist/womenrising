class Peer < ActiveRecord::Base
  belongs_to :peer1, class_name: "User", foreign_key: 'peer1_id'
  belongs_to :peer2, class_name: "User", foreign_key: 'peer2_id'
  belongs_to :peer3, class_name: "User", foreign_key: 'peer3_id'
  belongs_to :peer4, class_name: "User", foreign_key: 'peer4_id'

  after_save do
    self.send_mail
  end

  def send_mail
    if self.peer4 == nil
      UserMailer.three_peer_mail(self).deliver
    else
      UserMailer.four_peer_mail(self).deliver
    end
  end

  def self.automatially_create_groups
    remainder = []
    ["Technology","Business", "Startup"].each do |industry|
      (1..5).each do |stage_of_career|
        groups = create_groups(remainder, industry, stage_of_career)
        remainder = []
        outlyers = get_not_full_groups(groups)
        groups -= outlyers
        if outlyers.length > 0
          groups = reassign_not_full_groups(groups, outlyers.flatten)
          new_outlyers = get_not_full_groups(groups)
          groups -= new_outlyers
          if stage_of_career == 5
            groups = assign_group_no_checks(groups, new_outlyers.flatten)
          else
            remainder = new_outlyers
          end
        end
        create_peer_groups(groups)
      end
    end
  end

  def self.get_peers(industry, stage_of_career)
    User.where(is_participating_this_month: true, waitlist: false, live_in_detroit: true, is_assigned_peer_group: false, peer_industry: industry, stage_of_career: stage_of_career)
  end

  def self.get_one_peer(group)
    group.sample
  end

  def self.remove_peer(group, peer)
    group - [peer]
  end

  def self.check_interests(group, peer)
    group_interests = get_group_interests(group)
    return (peer.top_3_interests - group_interests).length < 3
  end

  def self.get_group_interests(group)
    group_interests = []
    group.each do |peer|
      if group_interests.empty?
        group_interests = peer.top_3_interests
      else
        differing_interest = group_interests - peer.top_3_interests
        group_interests -= differing_interest
      end
    end
    group_interests
  end

  def self.check_group(group, peer)
    return peer.current_goal == group[0].current_goal && check_interests(group, peer)
  end

  def self.assign_group(peer_groups, peer)
    peer_groups.each do |group|
      if check_group(group, peer) && group.length < 3
        group << peer
        return peer_groups
      end
    end
    return peer_groups << [peer]
  end

  def self.create_groups(all_groups, industry, stage_of_career)
    group = get_peers(industry, stage_of_career)
    peer_groups = all_groups
    while group.length > 0
      current_peer = get_one_peer(group)
      group = remove_peer(group, current_peer)
      peer_groups = assign_group(peer_groups, current_peer)
    end
    peer_groups
  end

  def self.reassign_not_full_groups(group, outlyers)
    outlyers = outlyers.flatten
    while outlyers.length > 0
      current_peer = get_one_peer(outlyers)
      outlyers = remove_peer(outlyers, current_peer)
      peer_groups = assign_group_no_cg(group, current_peer)
    end
    peer_groups
  end

  def self.get_not_full_groups(all_peer_groups)
    groups = all_peer_groups
    peer_groups = []
    groups.each do |group|
      if group.length < 3
        peer_groups << group
      end
    end
    peer_groups
  end

  def self.assign_group_no_cg(peer_groups, peer)
    peer_groups.each do |group|
      if check_interests(group, peer) && group.length < 3
        group << peer
        return peer_groups
      end
    end
    return peer_groups << [peer]
  end

  def self.create_peer_groups(groups)
    groups.each do |group|
      if check_valid_group(group)
        if group.length == 3
          Peer.create!(peer1:group[0],peer2:group[1],peer3:group[2])
          change_user(group)
        elsif group.length == 4
          Peer.create!(peer1:group[0],peer2:group[1],peer3:group[2],peer4:group[3])
          change_user(group)
        end
      end
    end
  end

  def self.change_user(group)
    group.each do |indv|
      indv.update(is_assigned_peer_group: true)
    end
  end

  def self.assign_group_no_checks(peer_groups, peers)
    while peers.length > 0
      if peers.length >= 3
        peer_sample = peers.sample(3)
        peer_groups << peer_sample
        peers -= peer_sample
      else
        peer = get_one_peer(peers)
        peers = remove_peer(peers, peer)
        peer_groups = assign_to_group_of_three(peer_groups, peer)
      end
    end
    peer_groups
  end

  def self.assign_to_group_of_three(peer_groups, peer)
    peer_groups.each do |group|
      if group.length < 4
        group << peer
        return peer_groups
      end
    end
  end

  def self.check_valid_group(group)
    is_valid = true
    group.each do |user|
      return is_valid = false if user.is_assigned_peer_group
    end
    is_valid
  end  

  def self.find_invalids(group)
    is_valid = []
    group.each do |user|
      is_valid << user if user.is_assigned_peer_group
    end
    is_valid
  end

  

end
