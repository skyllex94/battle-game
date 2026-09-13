using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class WeaponController : MonoBehaviour {

    public float speed;
    private Rigidbody2D rb;
    public class EnemyStats
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

    public EnemyStats Stats = new EnemyStats();

    void Update()
    {
        GetComponent<Rigidbody2D>().velocity = new Vector2(-speed, GetComponent<Rigidbody2D>().velocity.y);
    }

    void OnTriggerEnter2D(Collider2D other)
    {
        Player _player = other.GetComponent<Player>();
        Tower _tower = other.GetComponent<Tower>();
        Allies _ally = other.GetComponent<Allies>();
        Base _base = other.GetComponent<Base>();
        if (_player != null)
        {
            _player.DamagePlayer(Stats.damage);
        }
        if (_tower != null)
        {
            _tower.DamageTower(Stats.damage);
        }
        if (_ally != null)
        {
            _ally.DamageAlly(Stats.damage);
        }
        if (_base != null)
        {
            _base.DamageBase(Stats.damage);
        }
        Destroy(gameObject);
    }
}