using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityStandardAssets._2D;

public class ArmRotation : MonoBehaviour
{
    private GameMaster player;
    private PlatformerCharacter2D characterMovement;
    private GameObject playerMovement;
    private bool direction;
    GameObject weapon;
    private void Awake()
    {
        direction = true;
        weapon = this.gameObject.transform.Find("WeaponSlot").gameObject;
		 
    }
    void Update(){

		//if (Input.touchCount ==1 )
		//{
			//if((!IsPointerOverUIObject());


		if (Input.touchCount > 0)
		{
			if (!IsPointerOverUIObject() ){

				Debug.Log("New===>>"+  Input.touchCount);


				for (int i = 0; i < Input.touchCount; ++i)
				{
					if (Input.GetTouch(i).phase == TouchPhase.Began)
					{

				
				
									Vector3 difference = Camera.main.ScreenToWorldPoint(Input.GetTouch(i).position) - transform.position;
									difference.Normalize();

										float rotZ = Mathf.Atan2(difference.y, difference.x) * Mathf.Rad2Deg;
										 transform.rotation = Quaternion.Euler(0f, 0f, rotZ);

										 if (rotZ > 0f && rotZ < 100f || rotZ < 0f && rotZ > -90f)
									  {
										if (direction == false)
									  {
						                        direction = true;
						                        this.gameObject.GetComponent<SpriteRenderer>().flipY = false;
						                        weapon.gameObject.GetComponent<SpriteRenderer>().flipY = false;
						                        Flip();
						                    }

						                }
						                else if (rotZ > 100f && rotZ < 180f || rotZ < -90f && rotZ > -180f)
						                {
						                    if (direction == true)
						                    {
						                        direction = false;
						                        this.gameObject.GetComponent<SpriteRenderer>().flipY = true;
						                        weapon.gameObject.GetComponent<SpriteRenderer>().flipY = true;
						                        Flip();
						                    }

						                }
					}
				}
			}
		}
			


		
		//}
	}

    public void Right_ButtonClicked()
    {
        transform.rotation = Quaternion.Euler(0f, 0f, -15);

        this.gameObject.GetComponent<SpriteRenderer>().flipY = false;
        weapon.GetComponent<SpriteRenderer>().flipY = false;

    }

    public void Left_ButtonClicked()
    {
        transform.rotation = Quaternion.Euler(0f, 0f, -145);

        this.gameObject.GetComponent<SpriteRenderer>().flipY = true;
        weapon.GetComponent<SpriteRenderer>().flipY = true;
    }

    public void Flip()
    {
        if (GameObject.Find("Player") != null)
        {
            playerMovement = GameObject.Find("Player");
            characterMovement = playerMovement.GetComponent<PlatformerCharacter2D>();
        }
        else
        {
            playerMovement = GameObject.Find("Player(Clone)");
            characterMovement = playerMovement.GetComponent<PlatformerCharacter2D>();
        }
        if (direction == false && characterMovement.m_FacingRight == true || direction == true && characterMovement.m_FacingRight == false)
        {
            characterMovement.Flip();
        }
    }

    private bool IsPointerOverUIObject()
    {

        PointerEventData eventDataCurrentPosition = new PointerEventData(EventSystem.current);
        eventDataCurrentPosition.position = new Vector2(Input.mousePosition.x, Input.mousePosition.y);
        List<RaycastResult> results = new List<RaycastResult>();
        EventSystem.current.RaycastAll(eventDataCurrentPosition, results);
        return results.Count > 0;
    }
}
