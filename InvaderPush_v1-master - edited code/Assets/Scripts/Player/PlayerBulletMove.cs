using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class PlayerBulletMove : MonoBehaviour {

    public float moveSpeed = 200f;
    Rigidbody2D rb2d;
    Vector3 dir, mousePosition;
    public int damageAmount = 10;
    Vector3 hitPos;

    void Start()
    {
        rb2d = GetComponent<Rigidbody2D>();
		//int t = Input.touchCount;
		//mousePosition = new Vector3(Camera.main.ScreenToWorldPoint(Input.mousePosition).x, Camera.main.ScreenToWorldPoint(Input.mousePosition).y, 0);
		for (int i = 0; i < Input.touchCount; ++i)
		{
			mousePosition = new Vector3(Camera.main.ScreenToWorldPoint(Input.GetTouch(i).position).x, Camera.main.ScreenToWorldPoint(Input.GetTouch(i).position).y, 0);
	  		hitPos = (mousePosition - transform.position) * 30;
		}
		 


    }
    
    void FixedUpdate()
    {
        
	   // firepoint = transform.FindChild("FirePoint");
        dir = (hitPos - transform.position).normalized;
        rb2d.MovePosition(transform.position + (dir * moveSpeed)  * Time.deltaTime);
        Destroy(gameObject, 3f);
    }

    void OnTriggerEnter2D(Collider2D other)
    {
        Enemy enemy = other.GetComponent<Enemy>();
        EnemyTower etower = other.GetComponent<EnemyTower>();
        EnemyBase ebase = other.GetComponent<EnemyBase>();
        if (enemy != null)
        {
            enemy.DamageEnemy(damageAmount);
        }
        if (etower != null)
        {
            etower.DamageEnemyTower(damageAmount);
        }
        if (ebase != null)
        {
            ebase.DamageEnemyBase(damageAmount);
        }
        Destroy(gameObject);
    }
}
