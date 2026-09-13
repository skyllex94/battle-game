using System.Collections;
using System.Collections.Generic;
using UnityEngine;


public class Enemy : MonoBehaviour
{
    [System.Serializable]

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

    public GameObject HealthDrop;
    public GameObject WeaponDrop;
    public GameObject AmmoDrop;

    [Header("Optional:")]
    [SerializeField]
    private StatusIndicator statusIndicator;

    void Start()
    { //Initialize the stats for the object and set a statusbar indication
        Stats.Init();
        if (statusIndicator != null)
        {
            statusIndicator.SetHealth(Stats.curHealth, Stats.maxHealth);
        }
    }

    public void DamageEnemy(int damage)
    {
            Stats.curHealth -= damage;
            if (Stats.curHealth <= 0)
            {
                GameMaster.KillEnemy(this);
                int spawnChance = 20;  // Instantiating a loot based on a random chance percentage 
                float randomNum = Random.value * 100;
                if (randomNum < spawnChance)
                {
                    Instantiate(HealthDrop, transform.position, transform.rotation);
                }
                if ((randomNum > spawnChance) && (randomNum < 40))
                {
                    Instantiate(WeaponDrop, transform.position, transform.rotation);
                }
                if ((randomNum > 40) && (randomNum < 60))
                {
                    Instantiate(AmmoDrop, transform.position, transform.rotation);
                }
            }
            if (statusIndicator != null)
            {
                statusIndicator.SetHealth(Stats.curHealth, Stats.maxHealth);
            }
    }

    void OnCollisionEnter2D(Collision2D colliderInfo)
    {
        Player _player = colliderInfo.collider.GetComponent<Player>();
        Tower _tower = colliderInfo.collider.GetComponent<Tower>();
        if (_player != null)
        {
            _player.DamagePlayer(Stats.damage);       
        }
        if (_tower != null)
        {
            _tower.DamageTower(Stats.damage);
        }
    }
}
