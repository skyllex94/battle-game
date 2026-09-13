using Pathfinding;
using UnityEngine;
using System.Collections;

[RequireComponent (typeof(Rigidbody2D))]
[RequireComponent (typeof(Seeker))]
public class EnemyAI : MonoBehaviour {

    public Transform target;
    public float updateRate = 2f; // How many seconds we sill update per path

    private Seeker seeker;
    private Rigidbody2D rb;

    public Path path; //pathfinding

    public float speed = 300f;
    public ForceMode2D fMode;

    [HideInInspector]
    public bool PathIsEnded = false;
	// The max distance from the AI to a waypoint for it to continue to the next one
    public float nextWayPointDistance = 3;
    private int currentWayPoint = 0;  //Waypoint we are currently going for

    private bool searchingForPlayer = false;
    void Start () {
        seeker = GetComponent<Seeker>();
        rb = GetComponent<Rigidbody2D>();

        if (target == null) {
            if (!searchingForPlayer)
            {
                searchingForPlayer = true;
                StartCoroutine(SearchForPlayer());
            }
            return;
        }
        // start a new path to the target position ,returns  result from the function
        seeker.StartPath(transform.position, target.position, OnPathComplete);

        StartCoroutine (UpdatePath ());
    }

    IEnumerator SearchForPlayer(){
        GameObject sResult = GameObject.FindGameObjectWithTag("Player");
        if (sResult == null)
        {
            yield return new WaitForSeconds (0.5f);
            StartCoroutine(SearchForPlayer());
        }
        else
        {
            target = sResult.transform;
            searchingForPlayer = false;
            StartCoroutine (UpdatePath());
            yield return false;
        }
    }

    IEnumerator UpdatePath() {
        if (target == null)
        {
            if (!searchingForPlayer)
            {
                searchingForPlayer = true;
                StartCoroutine(SearchForPlayer());
            }
            yield return false;
        }
        seeker.StartPath(transform.position, target.position, OnPathComplete);
        yield return new WaitForSeconds(1f/updateRate);
        StartCoroutine (UpdatePath ());
    }
   
    public void OnPathComplete (Path p) {
        Debug.Log("We got a path" + p.error);
        if (!p.error) {
            path = p;
            currentWayPoint = 0;
        }
    }

    void FixedUpdate () {
        if (target == null)
        {
            if (!searchingForPlayer)
            {
                searchingForPlayer = true;
                StartCoroutine(SearchForPlayer());
            }
            return;
        }
        //TODO: Always look at the player

        if (path == null) {
            return;
        }

        if (currentWayPoint >= path.vectorPath.Count) {
            if (PathIsEnded) {
                return;
            }
            Debug.Log("End of the path!");
            PathIsEnded = true;
            return;
        }
        PathIsEnded = false;
        //Direction to next point
        Vector2 dir = (path.vectorPath[currentWayPoint] - transform.position).normalized;
        dir *= speed * Time.fixedDeltaTime;

        // Move to the approprite direction
        rb.AddForce(dir, fMode);
        float dist = Vector3.Distance (transform.position,path.vectorPath[currentWayPoint]);

        if (dist < nextWayPointDistance) {
            currentWayPoint++; 
            return;
        }
    }
}
