recruiting_system

=================

This project will provide system design and implementation for the recruiting process. We choose a recruiter as Source actor, worker as Target and Job as Note to design a framework which can be use to build the whole workflow of recruiting process. A recruiter can post a note about a job with several requirement tags, and worker can apply for that job. The job will go through a workflow until the recruiting process is done.

=================

The following is a list of PL/pgSQL functions that I have coded:

Create_workflow(): Used to create an empty workflow.
Drop_workflow(): Used to delete a workflow.
Get_workflow(): Used to get a list of all workflows that have been created.
Add_node(): Used to add a new node to a workflow
Get_node(): Used to get a list of all nodes in a workflow
Link_between(): Used to add an link between two nodes
Link_from_start(): Used to link from the special start node to the first node in the workflow
Link_to_finish(): Used to link from the last node in the workflow to the special finish node in the workflow
Get_children(): Used to get information on the children of a node
Create_job(): Used to create a job
Drop_job(): Used to delete a job
Get_job(): Used to get a list of jobs that have been created
Create_tag(): Used to create a tag
Drop_tag(): Used to delete a tag
Get_tag(): Used to get a list of tags in the given bundleid
Add_job_tag(): Used to link a job to a tag
Drop_job_tag(): Used to drop a relationship between a job and a tag
Get_job_tag(): Used to get a list of all tags in a job
Get_tag_job(): Used to get a list of all jobs that use the tag
Create_worker(): Used to create a worker
Get_worker(): Used to get a list of workers in the database
Add_applicant_tag(): Used to link an applicant to a tag
Drop_applicant_tag(): Used to drop a relationship between an applicant and a tag
Get_applicant_tag(): Used to get a list of all tags that an applicant has
Get_tag_applicant(): Used to get a list of all applicants that have the tag
Add_job_worker(): Used to link a job to a worker
Drop_job_worker(): Used to drop a relationship between a job and a worker
Get_job_worker(): Used to get a list of all workers that post or apply for the job
Get_worker_job(): Used to get a list of job that the worker either applied or posted
Add_job_log(): Used to record the job’s status (which node the job is at now)
Get_job_log(): Used to get a job’s history
Get_log_job(): Used to get a list of jobs that have been to the given node
