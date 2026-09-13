using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

public class CharacherUpgrade : MonoBehaviour{

    [SerializeField]
    private Text HealthText;
    [SerializeField]
    private Text SpeedText;
    [SerializeField]
    private float healthMultiplier = 1.3f;
    private PlayerStats stats;

    //private PlatformerCharacter2D charMovement;
    void OnEnable()
    {
        
        UpdateValues();
    }

    public void UpdateValues()
    {
        stats = PlayerStats.instance;
        HealthText.text = "HEALTH " + stats.maxHealth.ToString();
        //SpeedText.text = charMovement.m_maxSpeed.ToString();
    }

    public void UpgradeHealth()
    {
        stats.maxHealth = (int)(stats.maxHealth * healthMultiplier) + 1;
        UpdateValues();
    }
}
