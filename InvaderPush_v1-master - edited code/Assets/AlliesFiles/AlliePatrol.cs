using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class AlliePatrol : MonoBehaviour {

    public float moveSpeed;
    public bool moveRight;

    public Transform enemyCheck;
    public float enemyCheckRadius;
    public LayerMask whatToStopInfront;
    private bool reachingEnemy;

    //Timer variables for waiting between shooting
    public float waitBetweenShots;
    private float shotCounter;

    // Enemy emitting shots - variables for it
    public GameObject AllieBullet;
    public Transform firePoint;


	void Start () {
        shotCounter = 1;
	}
	
	void Update () {
        reachingEnemy = Physics2D.OverlapCircle(enemyCheck.position, enemyCheckRadius, whatToStopInfront);
        if (reachingEnemy)
        {
            shotCounter -= Time.deltaTime;
            moveSpeed = 0;
            if (shotCounter < 0)
            {
                GameObject bulletStar = (GameObject)Instantiate(AllieBullet, firePoint.position, firePoint.rotation);
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
        }
        else
        {
            GetComponent<Rigidbody2D>().velocity = new Vector2(-moveSpeed, GetComponent<Rigidbody2D>().velocity.y);
        }
	}
}
