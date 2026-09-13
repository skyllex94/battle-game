using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Enemy2Patrol : MonoBehaviour {

    public float moveSpeed;
    public bool moveRight;

    public Transform playerCheck;
    public float playerCheckRadius;
    public LayerMask whatToStopInfront;
    private bool reachingPlayer;

    //Timer variables for waiting between shooting
    public float waitBetweenShots;
    private float shotCounter;

    // Enemy emitting shots - variables for it
    public GameObject ninjaStar;
    public Transform firePoint;

	void Start () {
        shotCounter = 1;
	}
	
	void Update () {
        reachingPlayer = Physics2D.OverlapCircle(playerCheck.position, playerCheckRadius, whatToStopInfront);
        if (reachingPlayer)
        {
            shotCounter -= Time.deltaTime;
            moveSpeed = 0;
            if (shotCounter < 0)
            {
                GameObject bulletStar = (GameObject)Instantiate(ninjaStar, firePoint.position, firePoint.rotation);
                shotCounter = waitBetweenShots;
                Destroy(bulletStar, 4f);
            }
        }
        else
        {
            moveSpeed = 3;
        }

        if (moveRight)
        {
            GetComponent<Rigidbody2D>().velocity = new Vector2(moveSpeed, GetComponent<Rigidbody2D>().velocity.y);
        } else
        {
            GetComponent<Rigidbody2D>().velocity = new Vector2(-moveSpeed, GetComponent<Rigidbody2D>().velocity.y);
        }
	}
}
