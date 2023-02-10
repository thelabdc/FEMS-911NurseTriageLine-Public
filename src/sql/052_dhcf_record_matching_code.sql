-- Main Logic For Matching Records (=* is the soudex function)
-- Utilized by FEMS internally for matching on names Lab provided
-- This is not run in our front-to-back runs, but the point where this was executed
-- is referenced
((CATX(' ',t2.firstname_name1,t2.lastname_name1) =* t1.MemberFullName
OR CATX(' ',t2.firstname_name2,t2.lastname_name2) =* t1.MemberFullName)
AND t1.MemberDateofBirth = t2.date_of_birth)