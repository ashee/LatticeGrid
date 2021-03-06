  require 'organization_utilities'
  
def CreateInvestigatorFromHash(data_row)
  # assumed header values
	 # netid
	 # employee_id
	 # first_name
	 # last_name
	 # middle_name
	 # email
	 # rank
	 # campus
	 # career_track
	 # category
	 # degree
	 # dept_id
	 # division_id
	 # dv_abbr
	 # basis
	  
  pi = Investigator.new
  pi.username = data_row['NETID'] || data_row['USERNAME'] || data_row['netid'] || data_row['username']
  pi.employee_id = data_row['EMPLOYEE_ID'] || data_row['employee_id'] 
  pi.first_name = data_row['FIRST_NAME'] || data_row['first_name']
  pi.middle_name = data_row['MI'] || data_row['MIDDLE_NAME'] || data_row['mi'] || data_row['middle_name']
  pi.last_name = data_row['LAST_NAME'] || data_row['last_name'] 
  pi.email = data_row['EMAIL'] || data_row['email'] 
  pi.title = data_row['RANK'] || data_row['rank'] || data_row['TITLE'] || data_row['title'] 
  pi.business_phone = data_row['BUSINESS_PHONE'] || data_row['business_phone'] || data_row['OFFICE_PHONE'] || data_row['office_phone'] 
  pi.fax = data_row['FAX'] || data_row['fax'] 
  pi = SetDepartment(pi, data_row )
  pi.campus = data_row['CAMPUS'] || data_row['campus'] 
  pi.campus = pi.campus.gsub(/ *campus */i,'') if ! pi.campus.blank?
  pi.appointment_type = data_row['CATEGORY'] || data_row['category'] # Regular, Adjunct, Emeritus
  pi.appointment_track = data_row['CAREER_TRACK'] || data_row['career_track'] # research, clinician, clinician for CS, Clinician-Investigator
  pi.appointment_basis = data_row['BASIS'] || data_row['basis']
  pi.degrees = data_row['DEGREE'] || data_row['degree'] || data_row['DEGREES'] || data_row['degrees'] 
  pi.degrees = pi.degrees.gsub(/\//,",") if ! pi.degrees.blank?
  pi.pubmed_search_name = data_row['pubmed_search_name'] 
  pi.pubmed_limit_to_institution = data_row['pubmed_limit_to_institution'] if !data_row['pubmed_limit_to_institution'].blank?
  if pi.last_name.blank? && !data_row['NAME'].blank?
      pi=HandleName(pi,data_row['NAME'])
  end
  if pi.last_name.blank? && !data_row['name'].blank?
      pi=HandleName(pi,data_row['name'])
  end
  if pi.last_name.blank?
      puts "investigator does not have a last_name"
      puts data_row.inspect
  end
  if pi.username.blank?
    pi.username=pi.last_name+pi.first_name
  end
  pi.username = pi.username.split('.')[0]
  pi.username = pi.username.split('(')[0]
  pi.username = pi.username.gsub(/[' \t]+/,'')
  pi.username.downcase!
  
  if pi.username.blank? then
    puts "investigator #{pi.first_name} #{pi.last_name} does not have a username"
    puts data_row.inspect
  else
    existing_pi = Investigator.find_by_username(pi.username)
    if existing_pi.blank? then
      if pi.home_department_id.blank?
        puts "unable to set home_department_id for #{data_row}" if @verbose
      end
      pi.save!
    else
      # override existing record ?
      override=true
      existing_pi.employee_id = pi.employee_id if existing_pi.employee_id.blank?
      if existing_pi.first_name != pi.first_name
        puts "Existing first name and new first name different: existing: #{existing_pi.name}, new: #{pi.name} with username #{pi.username}"
        override=false
      end
      if override
        existing_pi.title = pi.title if !pi.title.blank?
        existing_pi.campus = pi.campus if !pi.campus.blank?
        existing_pi.appointment_type = pi.appointment_type if !pi.appointment_type.blank?
        existing_pi.appointment_track = pi.appointment_track if !pi.appointment_track.blank?
  #      existing_pi.secondary = pi.secondary if existing_pi.secondary.blank?
  #      existing_pi.division = pi.division if existing_pi.division.blank?
        existing_pi.email = pi.email if !pi.email.blank?
        existing_pi.employee_id = pi.employee_id if !pi.employee_id.blank?
        existing_pi.home_department_id = pi.home_department_id if !pi.home_department_id.blank?
        existing_pi.pubmed_search_name = pi.pubmed_search_name if !pi.pubmed_search_name.blank?
        existing_pi.pubmed_limit_to_institution = pi.pubmed_limit_to_institution if !pi.pubmed_limit_to_institution.blank?
      else
        existing_pi.title = pi.title if existing_pi.title.blank?
        existing_pi.campus = pi.campus if existing_pi.campus.blank?
        existing_pi.appointment_type = pi.appointment_type if existing_pi.appointment_type.blank?
        existing_pi.appointment_track = pi.appointment_track if existing_pi.appointment_track.blank?
  #      existing_pi.secondary = pi.secondary if existing_pi.secondary.blank?
  #      existing_pi.division = pi.division if existing_pi.division.blank?
        existing_pi.email = pi.email if existing_pi.email.blank?
        existing_pi.employee_id = pi.employee_id if existing_pi.employee_id.blank?
        existing_pi.home_department_id = pi.home_department_id if existing_pi.home_department_id.blank?
        existing_pi.pubmed_search_name = pi.pubmed_search_name if existing_pi.pubmed_search_name.blank?
        existing_pi.pubmed_limit_to_institution = pi.pubmed_limit_to_institution if existing_pi.pubmed_limit_to_institution.blank?
      end
      existing_pi.save
      pi = existing_pi
    end
    if ! data_row['program'].blank? then
      theProgram = CreateProgramFromName(data_row['program'])
      if theProgram.blank? then
        throw "unable to match program #{data_row['program']} for user #{pi.username}"
      end
      # replace this logic with a STI model of 'member??'
      membership = InvestigatorAppointment.find(:first, 
          :conditions=>['investigator_id=:investigator_id and organizational_unit_id=:program_id and type in (:types)', 
            {:program_id => theProgram.id, :investigator_id => pi.id, :types => ["Member"]}])
      if membership.blank?
        Member.create :organizational_unit_id => theProgram.id, :investigator_id => pi.id, :start_date => Time.now
      else
        membership.end_date = nil
        membership.updated_at = Time.now
        membership.save!  # update the record
      end
    else
      puts 'no program datarow'
	  end
	end
end

def HandleName(pi, name)
  return pi if name.blank? 
  pre, degrees = name.split(",")
  pi.degrees = degrees
  names = pre.split(" ")
  if ['I','II','III','Jr','Sr'].include?(names.last)
    pi.suffix = names.pop
  end
  if names.length < 2 || names.length > 3
    puts "investigator name is not valid - #{names}"
    puts pi.inspect
    return pi
  end
  if names.length == 2
    pi.first_name  = names[0]
    pi.last_name   = names[1]
  else
    pi.first_name  = names[0]
    pi.middle_name = names[1]
    pi.last_name   = names[2]
  end
  return pi
end


def InsertInvestigatorProgramsFromDepartments(pis)
  pis.each do |pi|
    theProgram = CreateProgramFromDepartment(pi.home_department)
    InsertInvestigatorProgram(pi,theProgram)
    theProgram = CreateProgramFromDepartment(pi.secondary)
    InsertInvestigatorProgram(pi,theProgram)
   end
end

def InsertInvestigatorProgram(pi,program)
  if !program.blank? && !program.id.blank? && !pi.id.blank? then
    begin
      ip = InvestigatorProgram.create :program_id => program.id, :investigator_id => pi.id, :program_appointment => 'member', :start_date => Time.now
    rescue Exception => error
       puts "something happened"+error
       throw pi.inspect
    end
  end
end

def CreateAppointment(data_row, type)
  # assumed header values
	 # division_id
	 # employee_id
  division_id = data_row["DIVISION_ID"]
  employee_id = data_row["EMPLOYEE_ID"]
  if division_id.blank? || employee_id.blank? then
     puts "Division_id or employee_id was blank or missing. datarow="+data_row.inspect
     return
  end  
  appt = InvestigatorAppointment.new
  division = OrganizationalUnit.find_by_division_id(division_id)
  investigator = Investigator.find_by_employee_id(employee_id)
  if  division.blank? then
     puts "Could not find Organization. datarow="+data_row.inspect
     return
  end
  if investigator.blank? then
      puts "Could not find Investigator. datarow="+data_row.inspect
      return
  end
  appt.type = type
  appt.organizational_unit_id = division.id
  appt.investigator_id = investigator.id
  exists = InvestigatorAppointment.find(:first, :conditions=>
    ['organizational_unit_id = :unit_id and investigator_id = :investigator_id and type = :type', 
      {:investigator_id => appt.investigator_id, :unit_id => appt.organizational_unit_id, :type => appt.type }])
  if exists.nil?
    appt.save
  end
end

def CreateJointAppointmentsFromHash(data_row)
  CreateAppointment(data_row, "Joint")
end

def CreateSecondaryAppointmentsFromHash(data_row)
     CreateAppointment(data_row, "Secondary")
end

def CreateCenterMembershipsFromHash(data_row)
     CreateAppointment(data_row, "Member")
end

def CreateProgramMembershipsFromHash(data_row, type='Member')
  # assumed header values
	 # Program	
	 # AppointmentType
	 # LastName
	 # FirstName
	 # email
   last_name = data_row["LastName"]
   first_name = data_row["FirstName"]
   unit_abbreviation = data_row["Program"]
  email = data_row["email"]
  if unit_abbreviation.blank? || (last_name.blank? and email.blank?) then
     puts "unit_abbreviation or email was blank or missing. datarow="+data_row.inspect
     return
  end  
  appt = InvestigatorAppointment.new
  program = OrganizationalUnit.find_by_abbreviation(unit_abbreviation)
  investigator=nil
  investigators = Investigator.find_all_by_last_name(last_name)
  if investigators.length == 1
    investigator = investigators[0]
  else
    investigator = Investigator.find_by_email(email.downcase)
    if investigator.blank? then
      more_pis = Investigator.find(:all, 
        :conditions => ["lower(last_name) = :last_name AND lower(first_name) like :first_name",
           {:last_name => last_name.downcase, :first_name => "#{first_name.downcase}%"}])
      if more_pis.length == 1
        investigator = more_pis[0]
      end
    end
   end
  if  program.blank? then
     puts "Could not find Organization. datarow="+data_row.inspect
     return
  end
  if investigator.blank? then
      puts "Could not find Investigator. datarow="+data_row.inspect
      puts "(found multiple investigators with last name #{last_name})" if investigators.length > 1
      return
  end
  appt.type = type
  appt.organizational_unit_id = program.id
  appt.investigator_id = investigator.id
  exists = InvestigatorAppointment.find(:first, :conditions=>
    ['organizational_unit_id = :unit_id and investigator_id = :investigator_id and type = :type', 
      {:investigator_id => appt.investigator_id, :unit_id => appt.organizational_unit_id, :type => appt.type }])
  if exists.nil?
    appt.save
  else
    # save so we can look at the update_at info for all members
    exists.update_attribute(:investigator_id, investigator.id) 
  end
 end

def prune_investigators_without_programs(investigators)
  investigators.each do |investigator|
    if investigator.investigator_appointments.nil?
      puts "pruning (setting deleted_at and end_date) for investigator #{investigator.name}" if @verbose
		investigator.deleted_at = 2.days.ago
		investigator.end_date = 2.days.ago
		investigator.save
    end
  end
end

def prune_program_memberships_not_updated()
  memberships = InvestigatorAppointment.all
  memberships.each do |membership|
    if membership.updated_at < 1.hour.ago
      puts "deleting membership entry for #{membership.investigator.name} username #{membership.investigator.username} in program #{membership.organizational_unit.name}" if @verbose
      membership.end_date = 2.days.ago
      membership.save! 
    end
  end
end

def doCleanInvestigators(investigators)
  puts "cleaning #{investigators.length} investigators" if @verbose
  investigators.each do |pi|
    begin
      pi.username = pi.username.split('.')[0]
      pi.username = pi.username.split('(')[0]
      pi.save!
    rescue
      puts "could not change #{pi.name} username to #{pi.username}"
    end
  end
end

def purgeInvestigators(investigators_to_purge)
  investigators_to_purge.each do |pi|
    pi.deleted_at = 2.days.ago
    pi.end_date = 2.days.ago
    pi.save
  end
end
  