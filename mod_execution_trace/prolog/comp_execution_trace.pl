:- module(comp_execution_trace,
    [
     	task/1,
	task_class/2,
	subtask/2,
	subtask_all/2,
      	task_goal/2,
	task_start/2,
	task_end/2,
	cram_holds/2,
	returned_value/2,
	belief_at/2,
	occurs/2,
	duration_of_a_task/2,
	javarun_designator/2,
	javarun_time_check/3,
	javarun_time_check2/3,
	javarun_location_check/3,
	javarun_perception_time_instances/2,
	javarun_perception_object_instances/2,
	javarun_loc_change/3,
	failure_class/2,
	failure_task/2,
	failure_attribute/3,
	show_image/1,
	image_of_percepted_scene/1,
	avg_task_duration/2,
	add_object_as_semantic_instance/4,
	arm_used_for_manipulation/2,
	add_robot_as_basic_semantic_instance/3,
	add_object_to_semantic_map/7,
	successful_instances_of_given_goal/2
    ]).
:- use_module(library('semweb/rdfs')).
:- use_module(library('semweb/owl')).
:- use_module(library('semweb/rdf_db')).
:- use_module(library('semweb/rdfs_computable')).
:- use_module(library('thea/owl_parser')).
:- use_module(library('comp_temporal')).
:- use_module(library('knowrob_mongo')).


:- rdf_db:rdf_register_ns(knowrob,  'http://ias.cs.tum.edu/kb/knowrob.owl#',  [keep(true)]).
:- rdf_db:rdf_register_ns(modexecutiontrace, 'http://ias.cs.tum.edu/kb/knowrob_cram.owl#', [keep(true)]).

% define holds as meta-predicate and allow the definitions
% to be in different parts of the source file
:- meta_predicate cram_holds(0, ?, ?).
:- discontiguous cram_holds/2.

:- meta_predicate occurs(0, ?, ?).
:- discontiguous occurs/2.

:- meta_predicate belief_at(0, ?, ?).
:- discontiguous belief_at/2.


% define predicates as rdf_meta predicates
% (i.e. rdf namespaces are automatically expanded)
:-  rdf_meta
    task(r),
    task_class(r,r),
    subtask(r,r),
    subtask_all(r,r),
    task_goal(r,r),
    task_start(r,r),
    task_end(r,r),
    belief_at(r,+),
    occurs(r,+),
    duration_of_a_task(r,-),
    cram_holds(r,+),
    returned_value(r,r),
    javarun_designator(+,-),
    javarun_time_check(+,+,-),
    javarun_time_check2(+,+,-),
    javarun_location_check(+,+,-),
    javarun_perception_time_instance(+,-),
    javarun_perception_object_instance(+,-),
    javarun_loc_change(r,r,r),
    failure_class(r,r),
    failure_task(r,r),
    failure_attribute(r,r,r),
    show_image(r),
    image_of_percepted_scene(r),
    avg_task_duration(r,-),
    add_object_as_semantic_instance(+,+,+,-),
    arm_used_for_manipulation(+,-),
    add_object_as_semantic_instance(+,+,-),
    add_object_to_semantic_map(+,+,+,-,+,+,+),
    successful_instances_of_given_goal(+,-).



task(Task) :-
	rdf_has(Task, rdf:type, A),
	rdf_reachable(A, rdfs:subClassOf, knowrob:'CRAMEvent').

task_class(Task, Class) :-
	rdf_has(Task, rdf:type, Class),
	rdf_reachable(Class, rdfs:subClassOf, knowrob:'CRAMEvent').

subtask(Task, Subtask) :-
	task(Task),
	task(Subtask),
	rdf_has(Task, knowrob:'subAction', Subtask).

subtask_all(Task, Subtask) :-
	subtask(Task, Subtask);

	nonvar(Task),
	subtask(Task, A),
	subtask_all(A, Subtask);


	nonvar(Subtask),
	subtask(A, Subtask),
	subtask_all(Task, A);


	var(Task),
	var(Subtask),
	subtask(Task, A),
	subtask_all(A, Subtask).

task_goal(Task, Goal) :-
	task(Task),
	rdf_has(Task, knowrob:'taskContext', literal(type(_, Goal)));
	
	task(Task),
	rdf_has(Task, knowrob:'goalContext', literal(type(_, Goal))).

task_start(Task, Start) :-
	task(Task),
	rdf_has(Task, knowrob:'startTime', Start).

task_end(Task, End) :-
	task(Task),
	rdf_has(Task, knowrob:'endTime', End).

belief_at(loc(Obj,Loc), Time) :-
		findall(
        		BeliefTime,
        		(   
			   task_class(Tsk, knowrob:'UIMAPerception'), 
			   task_end(Tsk, Bt), 
			   returned_value(Tsk, Obj),
			   term_to_atom(Bt, BeliefTime)     
        		),
        		BeliefTimes
    		),

		jpl_new( '[Ljava.lang.String;', BeliefTimes, Bts),
		term_to_atom(Time, TConverted),
		javarun_time_check2(Bts, TConverted, LastPerception),

		task_class(T, knowrob:'UIMAPerception'), 
		task_end(T, LastPerception), 
		returned_value(T, Obj),
		image_of_percepted_scene(T),
		image_of_percepted_scene(T), !,
		javarun_designator(Obj, Loc).

belief_at(robot(Part,Loc), Time) :-
		mng_lookup_transform('/map', Part, Time, Loc).


%it is not possible to extract that kind of information from current logs
occurs(loc_change(Obj),T) :-
	nonvar(Obj),
	nonvar(T),
	task_class(Task, knowrob:'UIMAPerception'),
	returned_value(Task, Obj),
        task_start(Task, T),
	rdf_has(Task, knowrob:'objectActedOn', Obj), 
	rdf_has(Obj, knowrob:'designator',Designator),
	javarun_loc_change(Obj, Designator, T).

occurs(object_perceived(Obj),T) :-
	nonvar(Obj),
	nonvar(T),
	task_class(Task, knowrob:'UIMAPerception'),
	returned_value(Task, Obj),
	task_start(Task, T).

cram_holds(task_status(Task, Status), T):-
	nonvar(Task),
	task(Task),
	task_start(Task, Start),
	task_end(Task, End),
	javarun_time_check(Start, T, Compare_Result1),
	javarun_time_check(T, End, Compare_Result2),
	term_to_atom(Compare_Result1, c1),
	term_to_atom(Compare_Result2, c2),
	((c1 is 1) -> (((c2 is 1) -> (Status = ['Continue']);(Status = ['Done'])));(((c2 is 1) -> (Status = ['Error']); (Status = ['NotStarted'])))).

cram_holds(object_visible(Object, Status), T):-
	nonvar(Object),
	nonvar(T),
	javarun_belief(Object, T, Loc),
	rdf_triple(comp_spatial:'m01', Loc, Result),
	term_to_atom(Result, r),
	((r is -1) -> (Status = [true]);(Status = [false])).

	%nonvar(Object),
	%var(T),
	%javarun_perception_time_instances(Object, T),
	%Status = [true];

	%var(Object),
	%nonvar(T),
	%javarun_perception_object_instances(T, Object),
	%Status = [true].

cram_holds(object_placed_at(Object, Loc), T):-
	javarun_belief(Object, T, Actual_Loc),
	javarun_time_check(Loc, Actual_Loc, Compare_Result),
	term_to_atom(Compare_Result, r),
	((r is 0) -> (true);(false)).

returned_value(Task, Obj) :-
	rdf_has(Task, rdf:type, knowrob:'UIMAPerception'),
	rdf_has(Task, knowrob:'perceptionResult', Obj);

	task(Task),
	failure_task(Obj, Task).

javarun_designator(Designator, Loc) :-
    jpl_new('edu.tum.cs.ias.knowrob.mod_execution_trace.ROSClient_low_level', ['my_low_level'], Client),
    jpl_call(Client, 'getBeliefByDesignator', [Designator], Localization_Array),
    jpl_array_to_list(Localization_Array, LocList),
    [M00, M01, M02, M03, M10, M11, M12, M13, M20, M21, M22, M23, M30, M31, M32, M33] = LocList,
    atomic_list_concat(['rotMat3D_',M00,'_',M01,'_',M02,'_',M03,'_',M10,'_',M11,'_',M12,'_',M13,'_',M20,'_',M21,'_',M22,'_',M23,'_',M30,'_',M31,'_',M32,'_',M33], LocIdentifier),

    atom_concat('http://ias.cs.tum.edu/kb/knowrob.owl#', LocIdentifier, Loc),
    rdf_assert(Loc, rdf:type, knowrob:'RotationMatrix3D'),
    rdf_assert(Loc,'http://ias.cs.tum.edu/kb/knowrob.owl#m00',literal(type(xsd:float, M00))),
    rdf_assert(Loc,'http://ias.cs.tum.edu/kb/knowrob.owl#m01',literal(type(xsd:float, M01))),
    rdf_assert(Loc,'http://ias.cs.tum.edu/kb/knowrob.owl#m02',literal(type(xsd:float, M02))),
    rdf_assert(Loc,'http://ias.cs.tum.edu/kb/knowrob.owl#m03',literal(type(xsd:float, M03))),
 
    rdf_assert(Loc,'http://ias.cs.tum.edu/kb/knowrob.owl#m10',literal(type(xsd:float, M10))),
    rdf_assert(Loc,'http://ias.cs.tum.edu/kb/knowrob.owl#m11',literal(type(xsd:float, M11))),
    rdf_assert(Loc,'http://ias.cs.tum.edu/kb/knowrob.owl#m12',literal(type(xsd:float, M12))),
    rdf_assert(Loc,'http://ias.cs.tum.edu/kb/knowrob.owl#m13',literal(type(xsd:float, M13))),
 
    rdf_assert(Loc,'http://ias.cs.tum.edu/kb/knowrob.owl#m20',literal(type(xsd:float, M20))),
    rdf_assert(Loc,'http://ias.cs.tum.edu/kb/knowrob.owl#m21',literal(type(xsd:float, M21))),
    rdf_assert(Loc,'http://ias.cs.tum.edu/kb/knowrob.owl#m22',literal(type(xsd:float, M22))),
    rdf_assert(Loc,'http://ias.cs.tum.edu/kb/knowrob.owl#m23',literal(type(xsd:float, M23))),
 
    rdf_assert(Loc,'http://ias.cs.tum.edu/kb/knowrob.owl#m30',literal(type(xsd:float, M30))),
    rdf_assert(Loc,'http://ias.cs.tum.edu/kb/knowrob.owl#m31',literal(type(xsd:float, M31))),
    rdf_assert(Loc,'http://ias.cs.tum.edu/kb/knowrob.owl#m32',literal(type(xsd:float, M32))),
    rdf_assert(Loc,'http://ias.cs.tum.edu/kb/knowrob.owl#m33',literal(type(xsd:float, M33))).

%Check whether given objec
javarun_loc_change(Obj, Designator, Time) :-
    % create ROS client object
    jpl_new('edu.tum.cs.ias.knowrob.mod_execution_trace.ROSClient_low_level', ['my_low_level'], Client),

    jpl_call(Client, 'checkLocationChange', [Obj, Designator, Time], Result),

    jpl_array_to_list(Result, ResultList),

    [Compare_Result] = ResultList,
    ((Compare_Result is -1) -> (false);((rdf_has(Compare_Result, rdf:type, knowrob:'HumanScaleObject')) -> (true);(false))).

%Check which time instance is earlier
javarun_time_check(Time1, Time2, Compare_Result) :-

    % create ROS client object
    jpl_new('edu.tum.cs.ias.knowrob.mod_execution_trace.ROSClient_low_level', ['my_low_level'], Client),

    jpl_call(Client, 'timeComparison', [Time1, Time2], Compare_Result).

%Check which time instance in the timelist is the latest but just before the time2 instance
javarun_time_check2(TimeList, Time2, Compare_Result) :-

    % create ROS client object
    jpl_new('edu.tum.cs.ias.knowrob.mod_execution_trace.ROSClient_low_level', ['my_low_level'], Client),

    jpl_call(Client, 'timeComparison2', [TimeList, Time2], Compare_Result).

%Check whether two location matrices are identical
javarun_location_check(L1, L2, Compare_Result) :-

    % create ROS client object
    jpl_new('edu.tum.cs.ias.knowrob.mod_execution_trace.ROSClient_low_level', ['my_low_level'], Client),

    jpl_call(Client, 'locationComparison', [L1, L2], Compare_Result).

%Get the perception designators time stamps as a list
javarun_perception_time_instances(Object, TimeList) :-

    % create ROS client object
    jpl_new('edu.tum.cs.ias.knowrob.mod_execution_trace.ROSClient_low_level', ['my_low_level'], Client),

    jpl_call(Client, 'getPerceptionTimeStamps', [Object], Times),

    jpl_array_to_list(Times, TimeList).

javarun_perception_object_instances(Time, ObjectList) :-
    % create ROS client object
    jpl_new('edu.tum.cs.ias.knowrob.mod_execution_trace.ROSClient_low_level', ['my_low_level'], Client),

    jpl_call(Client, 'getPerceptionObjects', [Time], Objects),

    jpl_array_to_list(Objects, ObjectList).

failure_class(Error, Class) :-
	rdf_has(Error, rdf:type, Class),
	rdf_reachable(Class, rdfs:subClassOf, knowrob:'CRAMFailure').

failure_task(Error, Task) :-
	task(Task),
	%failure_class(Error, Class),
	rdf_has(Task, knowrob:'eventFailure', Error).

failure_attribute(Error,AttributeName,Value) :-
	%failure_class(Error, Class),
	rdf_has(Error, AttributeName, Value).

show_image(Path) :-
	Path = literal(type(_A, B)),
	term_to_atom(B, PathNative),
	jpl_new('edu.tum.cs.ias.knowrob.mod_execution_trace.ROSClient_low_level', ['my_low_level'], Client),
        jpl_call(Client, 'publishImage', [PathNative], _R).

image_of_percepted_scene(T) :-
	task(T),
	rdf_has(T, knowrob:'capturedImage', Img),
	rdf_has(Img, knowrob:'linkToImageFile', Path),
	show_image(Path).

duration_of_a_task(T, Duration) :-
	task(T),
	task_start(T,S),
	task_end(T,E),
	rdf_split_url(_, StartPointLocal, S),
  	atom_concat('timepoint_', StartAtom, StartPointLocal),
  	term_to_atom(Start, StartAtom),
	rdf_split_url(_, EndPointLocal, E),
  	atom_concat('timepoint_', EndAtom, EndPointLocal),
  	term_to_atom(End, EndAtom),

  	jpl_new('edu.tum.cs.ias.knowrob.mod_execution_trace.ROSClient_low_level', ['my_low_level'], Client),
        jpl_call(Client, 'getDuration', [Start, End], Duration).



avg_task_duration(ActionType, AvgDuration) :-

  findall(D, (owl_individual_of(A, ActionType),
              rdf_triple(knowrob:duration, A, D)), Ds),

  sumlist(Ds, Sum),
  length(Ds, Len),
  Len \= 0,
  AvgDuration is Sum/Len.

add_object_as_semantic_instance(Obj, Matrix, Time, ObjInstance) :-
    add_object_to_semantic_map(Obj, Matrix, Time, ObjInstance, 0.2, 0.2, 0.2).

add_robot_as_basic_semantic_instance(Matrix, Time, ObjInstance) :-
    add_object_to_semantic_map(Time, Matrix, Time, ObjInstance, 0.5, 0.2, 0.2).

add_object_to_semantic_map(Obj, Matrix, Time, ObjInstance, H, W, D) :-
    rdf_split_url(_, ObjLocal, Obj),
    atom_concat('http://ias.cs.tum.edu/kb/cram_log.owl#Object_', ObjLocal, ObjInstance),
    rdf_assert(ObjInstance, rdf:type, 'http://ias.cs.tum.edu/kb/knowrob.owl#SpatialThing-Localized'),
    rdf_assert(ObjInstance,'http://ias.cs.tum.edu/kb/knowrob.owl#depthOfObject',literal(type(xsd:float, D))),
    rdf_assert(ObjInstance,'http://ias.cs.tum.edu/kb/knowrob.owl#widthOfObject',literal(type(xsd:float, W))),
    rdf_assert(ObjInstance,'http://ias.cs.tum.edu/kb/knowrob.owl#heightOfObject',literal(type(xsd:float, H))),
    rdf_assert(ObjInstance,'http://ias.cs.tum.edu/kb/knowrob.owl#describedInMap','http://ias.cs.tum.edu/kb/ias_semantic_map.owl#SemanticEnvironmentMap_PM580j'),

    atom_concat('http://ias.cs.tum.edu/kb/cram_log.owl#SemanticMapPerception_', ObjLocal, SemanticMapInstance),
    rdf_assert(SemanticMapInstance, rdf:type, 'http://ias.cs.tum.edu/kb/knowrob.owl#SemanticMapPerception'),
    rdf_assert(SemanticMapInstance, 'http://ias.cs.tum.edu/kb/knowrob.owl#objectActedOn', ObjInstance),
    rdf_assert(SemanticMapInstance, 'http://ias.cs.tum.edu/kb/knowrob.owl#eventOccursAt', Matrix),
    rdf_assert(SemanticMapInstance, 'http://ias.cs.tum.edu/kb/knowrob.owl#startTime', Time).

arm_used_for_manipulation(Task, Link) :-
    subtask_all(Task, Movement),
    task_class(Movement, knowrob:'ArmMovement'),
    rdf_has(Movement, knowrob:'voluntaryMovementDetails', Designator),

    jpl_new('edu.tum.cs.ias.knowrob.mod_execution_trace.ROSClient_low_level', ['my_low_level'], Client),
    jpl_call(Client, 'getArmLink', [Designator], Link).

successful_instances_of_given_goal(Goal, Tasks) :-	
     findall(T, (task_goal(T, Goal)), Ts),
     findall(FT, ((subtask(FT, S), task_goal(FT, Goal), rdf_has(S, knowrob:'caughtFailure', _F))), FTs),
     subtract(Ts, FTs, Tasks).	      

