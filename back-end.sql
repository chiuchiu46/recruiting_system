/******************** Workflow table ********************/

CREATE OR REPLACE FUNCTION r.create_workflow(
	r_name varchar(64),
	r_info text
)
RETURNS VOID AS $PROC$
BEGIN
	INSERT INTO r.workflow(name, info) VALUES (r_name, r_info);
END;
$PROC$ LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION r.drop_workflow (
	r_name varchar(64)
)
RETURNS void AS $PROC$	
BEGIN
	delete from r.workflow w where w.name = r_name; 
END;
$PROC$ LANGUAGE plpgsql; 



CREATE OR REPLACE FUNCTION r.get_workflow(	
)
RETURNS SETOF r.workflow AS $PROC$
DECLARE
	row1 r.workflow%ROWTYPE;	/* A row from the workflow table */
	row2 RECORD;
BEGIN
	FOR row2 IN 
		SELECT id, name, info
		FROM r.workflow
	LOOP
		row1.id := row2.id;
		row1.name := row2.name;
		row1.info := row2.info;
		RETURN NEXT row1;
	END LOOP;
	RETURN;
END;
$PROC$ LANGUAGE plpgsql; 



/******************** Node table ********************/

CREATE OR REPLACE FUNCTION r.add_node(	
	w_name varchar(64),
	n_sname char(3),
	n_name varchar(64),
	n_type r.ntypeD
)
RETURNS void AS $PROC$
DECLARE
	wid int;
BEGIN
	/* Check that we have a workflow -- if not, raise an exception */
	SELECT w.id INTO wid FROM r.workflow w WHERE w.name = w_name;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'the given workflow does not exist';
	END IF;
	
	INSERT INTO r.node(wid, name, sname, ntype) VALUES (wid, n_name, n_sname, n_type);
END;
$PROC$ LANGUAGE plpgsql; 



CREATE OR REPLACE FUNCTION r.get_node(
	w_name varchar(64)
)
RETURNS SETOF r.node AS $PROC$
DECLARE
	row1 r.node%ROWTYPE;	/* A row from the node table */
	row2 RECORD;
	w_id int;
BEGIN
	/* Check that we have a workflow -- if not, raise an exception */
	SELECT w.id INTO w_id FROM r.workflow w WHERE w.name = w_name;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'the given workflow does not exist';
	END IF;
	
	/* Check that we have a node -- if not, raise an exception */
	FOR row2 IN
		SELECT id, wid, name, sname, ntype
		FROM r.node n WHERE n.wid = w_id
	LOOP
		row1.id := row2.id;
		row1.wid := row2.wid;
		row1.name := row2.name;
		row1.sname := row2.sname;
		row1.ntype := row2.ntype;
		RETURN NEXT row1;
	END LOOP;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'currently no node for the workflow are created';
	END IF;
	RETURN;
END;
$PROC$ LANGUAGE plpgsql;



/******************** Link table ********************/

CREATE OR REPLACE FUNCTION r.link_between(
	w_name varchar(64),
	n_parent char(3),
	n_child char(3),
	l_guard varchar(100)
)
RETURNS VOID AS $PROC$
DECLARE
	pid int;
	cid int;
BEGIN
	/* Check that we parent node exist -- if not, raise an exception */
	SELECT n.id INTO pid FROM r.node n WHERE n.sname = n_parent;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'the given parent node does not exist';
	END IF;
	
	/* Check that we child node exist -- if not, raise an exception */
	SELECT n.id INTO cid FROM r.node n WHERE n.sname = n_child;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'the given child node does not exist';
	END IF;
	
	INSERT INTO r.link(parent, child, guard) VALUES (pid, cid, l_guard);
END;
$PROC$ LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION r.link_from_start(
	w_name varchar(64),
	new_child char(3),
	l_guard varchar(100)
)
RETURNS VOID AS $PROC$
DECLARE
	w_id int;
	sid int;
	cid int;
BEGIN
	/* Check that we have a workflow -- if not, raise an exception */
	SELECT w.id INTO w_id FROM r.workflow w WHERE w.name = w_name;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'the given workflow does not exist';
	END IF;
	
	/* Check that the given node exist -- if not, raise an exception */
	/* the given node will become the new child node */
	SELECT n.id INTO cid FROM r.node n WHERE n.sname = new_child AND n.wid = w_id;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'the given node does not exist';
	END IF;
	
	/* Check that there exist a start node in the given workflow */
	SELECT n.id INTO sid FROM r.node n WHERE n.ntype = 'S' AND n.wid = w_id;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'there is no start node in the given workflow';
	END IF;
	
	/* Check that there doesn't exist the same link from the start node to the given node */
	PERFORM * FROM r.link WHERE parent = sid AND child = cid;
	IF FOUND THEN
		RAISE EXCEPTION 'the link already exist';
	END IF;
	
	/* Check that the given node is not the same as the start node */
	IF sid = cid THEN 
		RAISE EXCEPTION 'a node cannot link to itself';
	END IF;
	
	/* add link between new node and the first node in the workflow */
	INSERT INTO r.link(parent, child, guard) VALUES (sid, cid, l_guard);
END;
$PROC$ LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION r.link_to_finish(
	w_name varchar(64),
	new_parent char(3),
	l_guard varchar(100)
)
RETURNS VOID AS $PROC$
DECLARE	
	w_id int;
	pid int;
	eid int;
	row r.node%ROWTYPE;	/* A row from the node table */
BEGIN	
	/* Check that we have a workflow -- if not, raise an exception */
	SELECT w.id INTO w_id FROM r.workflow w WHERE w.name = w_name;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'the given workflow does not exist';
	END IF;
	
	/* Check that the given node exist -- if not, raise an exception */
	/* the given node will become the new parent node */
	SELECT n.id INTO pid FROM r.node n WHERE n.sname = new_parent AND n.wid = w_id;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'the given node does not exist';
	END IF;
	
	/* Check that there exist a end node in the given workflow */
	SELECT n.id INTO eid FROM r.node n WHERE n.ntype = 'E' AND n.wid = w_id;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'there is no end node in the given workflow';
	END IF;
	
	/* Check that there doesn't exist the same link from the end node to the given node */
	PERFORM * FROM r.link WHERE parent = pid AND child = eid;
	IF FOUND THEN
		RAISE EXCEPTION 'the link already exist';
	END IF;
	
	/* Check that the given node is not the same as the start node */
	IF pid = eid THEN 
		RAISE EXCEPTION 'a node cannot link to itself';
	END IF;
	
	/* add link between new node and the first node in the workflow */
	INSERT INTO r.link(parent, child, guard) VALUES (pid, eid, l_guard);
END;
$PROC$ LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION r.get_children(
	w_name varchar(64),
	n_sname char(3)
)
RETURNS SETOF r.node AS $PROC$
DECLARE
	row1 r.node%ROWTYPE;	/* A row from the node table */
	row2 RECORD;
	pid int;
BEGIN
	/* Check that we have a parent node -- if not, raise an exception */
	SELECT n.id INTO pid FROM r.node n WHERE n.sname = n_sname;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'the given node does not exist';
	END IF;
	
	FOR row2 IN
		SELECT id, wid, name, sname, ntype
		FROM r.node n WHERE n.id = ANY
		(SELECT l.child FROM r.link l WHERE l.parent = pid)
	LOOP
		row1.id := row2.id;
		row1.wid := row2.wid;
		row1.name := row2.name;
		row1.sname := row2.sname;
		row1.ntype := row2.ntype;
		RETURN NEXT row1;
	END LOOP;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'currently the given node does not have a child node';
	END IF;
	RETURN;
END;
$PROC$ LANGUAGE plpgsql;



/******************** Job table ********************/

CREATE OR REPLACE FUNCTION r.create_job (
	r_wname			varchar(64),
	r_name			varchar(100),
	r_location		varchar(30),
	r_type			r.jtyped,
	r_salary		numeric,
	r_description	text
)
RETURNS VOID AS $PROC$
DECLARE
	wid int;
BEGIN
	/* Check that the given workflow exist -- if not, raise an exception */
	SELECT w.id INTO wid FROM r.workflow w WHERE w.name = r_wname;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'the given workflow does not exist';
	END IF;
	
	INSERT INTO r.job(wid, name, location, jtype, salary, description) 
			VALUES (r_wid, r_name, r_location, r_type, r_salary, r_description);
END;
$PROC$ LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION r.drop_job (
	r_id int
)
RETURNS void AS $PROC$	
BEGIN
	delete from r.job j where j.id = r_id; 
END;
$PROC$ LANGUAGE plpgsql; 



CREATE OR REPLACE FUNCTION r.get_job (	
)
RETURNS SETOF r.job AS $PROC$
DECLARE
	row1 r.job%ROWTYPE;	/* A row from the job table */
	row2 RECORD;
BEGIN
	FOR row2 IN 
		SELECT id, wid, name, location, jtype, salary, description
		FROM r.job
	LOOP
		row1.id := row2.id;
		row1.wid := row2.wid;
		row1.name := row2.name;
		row1.location := row2.location;
		row1.jtype := row2.jtype;
		row1.salary := row2.salary;
		row1.description := row2.description;
		RETURN NEXT row1;
	END LOOP;
	RETURN;
END;
$PROC$ LANGUAGE plpgsql; 



/******************** Tag table ********************/

CREATE OR REPLACE FUNCTION r.create_tag (
	r_bundleid		int,
	r_name			varchar(50),
	r_description	text
)
RETURNS VOID AS $PROC$
BEGIN
	INSERT INTO r.tag(bundleid, name, description) 
			VALUES (r_bundleid, r_name, r_description);
END;
$PROC$ LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION r.drop_tag (
	r_name varchar(50)
)
RETURNS void AS $PROC$	
BEGIN
	delete from r.tag t where t.name = r_name; 
END;
$PROC$ LANGUAGE plpgsql; 



CREATE OR REPLACE FUNCTION r.get_tag(
	r_bname		varchar(50)
)
RETURNS SETOF r.tag AS $PROC$
DECLARE
	row1 r.tag%ROWTYPE;	/* A row from the tag table */
	row2 RECORD;
	r_bundleid int;
BEGIN
	/* Check that the given bundle exist -- if not, raise an exception */
	SELECT t.id INTO r_bundleid FROM r.tag t WHERE t.name = r_bname;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'the given bundle does not exist';
	END IF;
	
	/* Check that the bundle has any tag -- if not, raise an exception */
	FOR row2 IN
		SELECT id, bundleid, name, description
		FROM r.tag t WHERE t.bundleid = r_bundleid
	LOOP
		row1.id := row2.id;
		row1.bundleid := row2.bundleid;
		row1.name := row2.name;
		row1.description := row2.description;
		RETURN NEXT row1;
	END LOOP;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'currently the bundle has zero tag';
	END IF;
	RETURN;
END;
$PROC$ LANGUAGE plpgsql;



/******************** Job_tag table ********************/

CREATE OR REPLACE FUNCTION r.add_job_tag(
	r_jid	int,
	r_tid	int
)
RETURNS void AS $PROC$
BEGIN
	/* Check that the given job exist -- if not, raise an exception */
	PERFORM j.id FROM r.job j WHERE j.id = r_jid;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'the given job does not exist';
	END IF;
	
	/* Check that the given tag exist -- if not, raise an exception */
	PERFORM t.id FROM r.tag t WHERE t.id = r_tid;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'the given tag does not exist';
	END IF;
	
	INSERT INTO r.job_tag(jid, tid) VALUES (r_jid, r_tid);
END;
$PROC$ LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION r.drop_job_tag (
	r_jid	int,
	r_tid	int
)
RETURNS void AS $PROC$	
BEGIN
	delete from r.job_tag jt where jt.jid = r_jid and jt.tid = r_tid; 
END;
$PROC$ LANGUAGE plpgsql; 



CREATE OR REPLACE FUNCTION r.get_job_tag(
	r_jid	int
)
RETURNS SETOF r.job_tag AS $PROC$
DECLARE
	row1 r.job_tag%ROWTYPE;	/* A row from the job_tag table */
	row2 RECORD;
BEGIN
	/* Check that the job exist -- if not, raise an exception */
	PERFORM j.id FROM r.job j WHERE j.id = r_jid;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'the given job does not exist';
	END IF;
	
	/* Check that we have a tag -- if not, raise an exception */
	FOR row2 IN
		SELECT jid, tid
		FROM r.job_tag jt WHERE jt.jid = r_jid
	LOOP
		row1.jid := row2.jid;
		row1.tid := row2.tid;
		RETURN NEXT row1;
	END LOOP;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'currently the given job does not have any tag';
	END IF;
	RETURN;
END;
$PROC$ LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION r.get_tag_job (
	r_tid	int
)
RETURNS SETOF r.job_tag AS $PROC$
DECLARE
	row1 r.job_tag%ROWTYPE;	/* A row from the job_tag table */
	row2 RECORD;
BEGIN
	/* Check that the tag exist -- if not, raise an exception */
	PERFORM t.id FROM r.tag t WHERE t.id = r_tid;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'the given tag does not exist';
	END IF;
	
	/* Check that we have a tag -- if not, raise an exception */
	FOR row2 IN
		SELECT jid, tid
		FROM r.job_tag jt WHERE jt.tid = r_tid
	LOOP
		row1.jid := row2.jid;
		row1.tid := row2.tid;
		RETURN NEXT row1;
	END LOOP;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'currently no job requires the given tag';
	END IF;
	RETURN;
END;
$PROC$ LANGUAGE plpgsql;



/******************** Worker table ********************/

CREATE OR REPLACE FUNCTION r.create_worker (
	r_fname			varchar(30),
	r_lname			varchar(30),
	r_age			int,
	r_gender		r.genderd
)
RETURNS VOID AS $PROC$
BEGIN
	INSERT INTO r.worker(fname, lname, age, gender) 
			VALUES (r_fname, r_lname, r_age, r_gender);
END;
$PROC$ LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION r.get_worker (	
)
RETURNS SETOF r.worker AS $PROC$
DECLARE
	row1 r.worker%ROWTYPE;	/* A row from the worker table */
	row2 RECORD;
BEGIN
	FOR row2 IN 
		SELECT id, fname, lname, age, gender
		FROM r.worker
	LOOP
		row1.id := row2.id;
		row1.fname := row2.fname;
		row1.lname := row2.lname;
		row1.age := row2.age;
		row1.gender := row2.gender;
		RETURN NEXT row1;
	END LOOP;
	RETURN;
END;
$PROC$ LANGUAGE plpgsql; 



/******************** Applicant_tag table ********************/

CREATE OR REPLACE FUNCTION r.add_applicant_tag(
	r_aid	int,
	r_tid	int
)
RETURNS void AS $PROC$
BEGIN
	/* Check that the given worker/applicant exist -- if not, raise an exception */
	PERFORM w.id FROM r.worker w WHERE w.id = r_aid;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'the given applicant does not exist';
	END IF;
	
	/* Check that the given tag exist -- if not, raise an exception */
	PERFORM t.id FROM r.tag t WHERE t.id = r_tid;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'the given tag does not exist';
	END IF;
	
	INSERT INTO r.applicant_tag(aid, tid) VALUES (r_aid, r_tid);
END;
$PROC$ LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION r.drop_applicant_tag (
	r_aid	int,
	r_tid	int
)
RETURNS void AS $PROC$	
BEGIN
	delete from r.applicant_tag a where a.aid = r_aid and a.tid = r_tid; 
END;
$PROC$ LANGUAGE plpgsql; 



CREATE OR REPLACE FUNCTION r.get_applicant_tag(
	r_aid	int
)
RETURNS SETOF r.applicant_tag AS $PROC$
DECLARE
	row1 r.applicant_tag%ROWTYPE;	/* A row from the applicant_tag table */
	row2 RECORD;
BEGIN
	/* Check that the applicant exist -- if not, raise an exception */
	PERFORM w.id FROM r.worker w WHERE w.id = r_aid;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'the given applicant does not exist';
	END IF;
	
	/* Check that we have a tag -- if not, raise an exception */
	FOR row2 IN
		SELECT aid, tid
		FROM r.applicant_tag a WHERE a.aid = r_aid
	LOOP
		row1.aid := row2.aid;
		row1.tid := row2.tid;
		RETURN NEXT row1;
	END LOOP;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'currently the given applicant does not have any tag';
	END IF;
	RETURN;
END;
$PROC$ LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION r.get_tag_applicant (
	r_tid	int
)
RETURNS SETOF r.applicant_tag AS $PROC$
DECLARE
	row1 r.applicant_tag%ROWTYPE;	/* A row from the applicant_tag table */
	row2 RECORD;
BEGIN
	/* Check that the tag exist -- if not, raise an exception */
	PERFORM t.id FROM r.tag t WHERE t.id = r_tid;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'the given tag does not exist';
	END IF;
	
	/* Check that we have an applicant -- if not, raise an exception */
	FOR row2 IN
		SELECT aid, tid
		FROM r.applicant_tag a WHERE a.tid = r_tid
	LOOP
		row1.aid := row2.aid;
		row1.tid := row2.tid;
		RETURN NEXT row1;
	END LOOP;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'currently no applicants have the given tag';
	END IF;
	RETURN;
END;
$PROC$ LANGUAGE plpgsql;



/******************** Job_worker table ********************/

CREATE OR REPLACE FUNCTION r.add_job_worker (
	r_jid	int,
	r_wid	int,
	r_wtype	r.wtyped
)
RETURNS void AS $PROC$
BEGIN
	/* Check that the given worker exist -- if not, raise an exception */
	PERFORM w.id FROM r.worker w WHERE w.id = r_wid;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'the given worker does not exist';
	END IF;
	
	/* Check that the given job exist -- if not, raise an exception */
	PERFORM j.id FROM r.job j WHERE j.id = r_jid;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'the given job does not exist';
	END IF;
	
	INSERT INTO r.job_worker(jid, workerid, wtype) VALUES (r_jid, r_wid, r_wtype);
END;
$PROC$ LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION r.drop_job_worker (
	r_jid	int,
	r_wid	int
)
RETURNS void AS $PROC$	
BEGIN
	delete from r.job_worker jw where jw.jid = r_jid and jw.workerid = r_wid; 
END;
$PROC$ LANGUAGE plpgsql; 



CREATE OR REPLACE FUNCTION r.get_job_worker (
	r_jid	int
)
RETURNS SETOF r.job_worker AS $PROC$
DECLARE
	row1 r.job_worker%ROWTYPE;	/* A row from the job_worker table */
	row2 RECORD;
BEGIN
	/* Check that the given job exist -- if not, raise an exception */
	PERFORM j.id FROM r.job j WHERE j.id = r_jid;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'the given job does not exist';
	END IF;
	
	/* Check that we have a worker -- if not, raise an exception */
	FOR row2 IN
		SELECT jid, workerid, wtype
		FROM r.job_worker jw WHERE jw.jid = r_jid
	LOOP
		row1.jid := row2.jid;
		row1.workerid := row2.workerid;
		row1.wtype := row2.wtype;
		RETURN NEXT row1;
	END LOOP;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'currently the given job does not have relationship to any worker';
	END IF;
	RETURN;
END;
$PROC$ LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION r.get_worker_job (
	r_wid	int
)
RETURNS SETOF r.job_worker AS $PROC$
DECLARE
	row1 r.job_worker%ROWTYPE;	/* A row from the job_worker table */
	row2 RECORD;
BEGIN
	/* Check that the given worker exist -- if not, raise an exception */
	PERFORM w.id FROM r.worker w WHERE w.id = r_wid;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'the given worker does not exist';
	END IF;
	
	/* Check that we have a job -- if not, raise an exception */
	FOR row2 IN
		SELECT jid, workerid, wtype
		FROM r.job_worker jw WHERE jw.workerid = r_wid
	LOOP
		row1.jid := row2.jid;
		row1.workerid := row2.workerid;
		row1.wtype := row2.wtype;
		RETURN NEXT row1;
	END LOOP;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'currently the given worker have not post or apply to any job';
	END IF;
	RETURN;
END;
$PROC$ LANGUAGE plpgsql;



/******************** Job_log table ********************/

CREATE OR REPLACE FUNCTION r.add_job_log (
	r_jid	int,
	r_nid	int
)
RETURNS void AS $PROC$
BEGIN
	/* Check that the given job exist -- if not, raise an exception */
	PERFORM j.id FROM r.job j WHERE j.id = r_jid;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'the given job does not exist';
	END IF;
	
	/* Check that the given node exist -- if not, raise an exception */
	PERFORM n.id FROM r.node n WHERE n.id = r_nid;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'the given node does not exist';
	END IF;
	
	INSERT INTO r.job_log(jid, nid, time) VALUES (r_jid, r_nid, clock_timestamp());
END;
$PROC$ LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION r.get_job_log (
	r_jid	int
)
RETURNS SETOF r.job_log AS $PROC$
DECLARE
	row1 r.job_log%ROWTYPE;	/* A row from the job_log table */
	row2 RECORD;
BEGIN
	/* Check that the given job exist -- if not, raise an exception */
	PERFORM j.id FROM r.job j WHERE j.id = r_jid;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'the given job does not exist';
	END IF;
	
	/* Check that we have a record -- if not, raise an exception */
	FOR row2 IN
		SELECT jid, nid, time
		FROM r.job_log jl WHERE jl.jid = r_jid
	LOOP
		row1.jid := row2.jid;
		row1.nid := row2.nid;
		row1.time := row2.time;
		RETURN NEXT row1;
	END LOOP;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'currently the given job does not a history record';
	END IF;
	RETURN;
END;
$PROC$ LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION r.get_log_job (
	r_nid	int
)
RETURNS SETOF r.job_log AS $PROC$
DECLARE
	row1 r.job_log%ROWTYPE;	/* A row from the job_log table */
	row2 RECORD;
BEGIN
	/* Check that the given node exist -- if not, raise an exception */
	PERFORM n.id FROM r.node n WHERE n.id = r_nid;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'the given node does not exist';
	END IF;
	
	/* Check if any job has been to the given node -- if not, raise an exception */
	FOR row2 IN
		SELECT jid, nid, time
		FROM r.job_log jl WHERE jl.nid = r_nid
	LOOP
		row1.jid := row2.jid;
		row1.nid := row2.nid;
		row1.time := row2.time;
		RETURN NEXT row1;
	END LOOP;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'currently no job have been to the given node';
	END IF;
	RETURN;
END;
$PROC$ LANGUAGE plpgsql;