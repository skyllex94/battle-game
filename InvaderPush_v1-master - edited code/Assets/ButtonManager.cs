using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.SceneManagement;

public class ButtonManager : MonoBehaviour {

    [SerializeField]
    GameObject UpgradePopup;

    public void BackButton()
    {
        SceneManager.LoadScene("MainMenu");
    }

    public void UpgradeMenuPopup()
    {
        UpgradePopup.SetActive(!UpgradePopup.activeSelf);
    }

    public void Location1()
    {
        SceneManager.LoadScene("LevelSelection1");
    }
}
