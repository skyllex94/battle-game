using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class AllieBulletControl : MonoBehaviour {

    public float speed;
    private Rigidbody2D rb;

    public class AllieStats
    {
        public int maxHealth = 100;
        private int _curHealth;
        public int curHealth
        {
            get { return _curHealth; }
            set { _curHealth = Mathf.Clamp(value, 0, maxHealth); }
        }
        public void Init()
        {
            curHealth = maxHealth;
        }
        public int damage = 40;

    }

    public AllieStats Stats = new AllieStats();

	void Start () {
		
	}
	
	void Update () {
        GetComponent<Rigidbody2D>().velocity = new Vector2(speed, GetComponent<Rigidbody2D>().velocity.y);
	}

    void OnTriggerEnter2D(Collider2D other)
    {
        Enemy _enemy = other.GetComponent<Enemy>();
        EnemyTower _enemytower = other.GetComponent<EnemyTower>();
        EnemyBase _enemybase = other.GetComponent<EnemyBase>();
        if (_enemy != null)
        {
            _enemy.DamageEnemy(Stats.damage);
        }
        if (_enemytower != null)
        {
            _enemytower.DamageEnemyTower(Stats.damage);
        }
        if (_enemybase != null)
        {
            _enemybase.DamageEnemyBase(Stats.damage);
        }
        Destroy(gameObject);
    }
}
