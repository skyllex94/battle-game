using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class EnemyTower : MonoBehaviour {

    [SerializeField]
    private StatusIndicator statusIndicator;

    public class EnemyTowerStats
    {
        public int maxHealth = 200;
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
    }

    public EnemyTowerStats Stats = new EnemyTowerStats();

    void Start()
    {   //Initialize the stats for the object and set a statusbar indication
        Stats.Init();
        if (statusIndicator != null)
        {
            statusIndicator.SetHealth(Stats.curHealth, Stats.maxHealth);
        }
    }

    public void DamageEnemyTower(int damage)
    {
        Stats.curHealth -= damage;
        if (Stats.curHealth <= 0)
        {
            GameMaster.DestroyEnemyTower(this);
        }
        if (statusIndicator != null)
        {
            statusIndicator.SetHealth(Stats.curHealth, Stats.maxHealth);
        }
    }
}
